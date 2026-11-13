package dev.nolyf.dsh_red.runtime

import android.content.Context
import android.os.Process as AndroidProcess
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import dev.nolyf.dsh_red.phone.PhoneGuest
import java.io.File
import java.io.IOException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.nio.file.Files
import java.nio.file.NoSuchFileException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/**
 * Runs `dsh web` through proot or the optional direct glibc planner, using the
 * same composed manifest configuration. Reports ready after the token and socket.
 */
/**
 * Runs [command] as root (Magisk's `su`) and returns its combined output.
 *
 * The launch happens here, in the reviewed owner: a native child started
 * anywhere else would inherit the app's configuration file descriptors.
 */
internal fun runRootCommand(su: String, command: String, timeoutMs: Long = 600_000): String {
    val process = ProcessBuilder(su, "-c", command).redirectErrorStream(true).start()
    process.outputStream.close()
    val out = process.inputStream.bufferedReader().readText()
    if (!process.waitFor(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS)) {
        process.destroyForcibly()
        throw IllegalStateException("root command timed out: ${command.take(80)}")
    }
    if (process.exitValue() != 0) {
        throw IllegalStateException("root command failed (${process.exitValue()}): ${command.take(120)}\n$out")
    }
    return out
}

class DshProcess(
    private val context: Context,
    private val manifest: RuntimeManifest,
    private val rootfs: File,
    private val listener: Listener,
) {
    interface Listener {
        fun onLog(line: String, stream: String)
        fun onReady(source: DshProcess, baseUrl: String, token: String)
        fun onExit(source: DshProcess, code: Int, expected: Boolean)
        /** Called under the process monitor: enqueue owner updates without waiting for its lock. */
        fun onStartupFailure(source: DshProcess)
        /** The start is busy turning PRoot's fake hard links into real files (true), or done (false). */
        fun onTidying(active: Boolean) {}
    }

    @Volatile private var process: Process? = null
    @Volatile private var stopping = false
    @Volatile private var expectedExit = false
    @Volatile private var readyReported = false
    private val startupSignal = CountDownLatch(1)
    @Volatile private var waiter: Thread? = null
    @Volatile private var stopper: Thread? = null
    // Share captured identities across launcher replacement within this app
    // process. Both capture and cleanup use the shared state's monitor.
    private val cleanupState by lazy {
        RuntimeProcessOwnership.cleanupState(rootfs.canonicalPath, AndroidProcess.myUid())
    }
    private val cleanupKnown get() = cleanupState.known
    var port: Int = DEFAULT_PORT
        private set

    @Volatile var startupError: String? = null
        private set

    @Volatile var startupTokenTimedOut: Boolean = false
        private set

    /** The launch command got the phone-control overlay (see [PhoneGuest.launchArg]). */
    var phoneMounted: Boolean = false
        private set

    /** Actual method for this process, fixed before it can be spawned. Safe mode stays proot. */
    var direct: Boolean = false
        private set

    val launchDiagnostics = LaunchDiagnostics()
    val executionMode: String? get() = launchDiagnostics.currentMode(process?.isAlive == true)

    var directFallbackReason: String? = null
        private set

    /**
     * [binds] are extra proot `-b host:guest` mounts, inserted before the guest command.
     * [safe] boots the rescue profile instead of `web` (see [SafeMode.profileArg]).
     */
    fun start(guestEnv: Map<String, String>, binds: List<String> = emptyList(), safe: Boolean = false, phone: Boolean = false, directEngine: Boolean = false, directFailed: Boolean = false, searchOverlay: Boolean = false, authOverlay: Boolean = false, speechOverlay: Boolean = false, onLaunchMethod: ((Boolean) -> Unit)? = null) {
        check(process == null) { "already started" }
        // The engine runs in a real chroot: no PRoot, no ptrace.
        val cleanup = reapStrays(allowObservationGap = true)
        directFallbackReason = null
        launchDiagnostics.selected(false, null)
        direct = false
        check(cleanup.complete || !cleanup.ownedRemaining) { "runtime cleanup incomplete; stop the engine and retry" }
        if (!cleanup.complete) listener.onLog("[dsh-app] starting the engine with incomplete process observation", "system")
        // An engine from an earlier run is still there when the app was killed
        // or the phone rebooted the service. It runs as root, so the app can
        // neither see nor stop it: it keeps the port and the write lock of the
        // chats it had open, and the app then talks to an engine that is not
        // its own. Root ends it before this launch.
        val leftovers = ChrootRuntime.killLeftoverEngines()
        if (leftovers > 0) {
            listener.onLog("[dsh-app] stopped $leftovers engine process(es) left over from an earlier run", "system")
        }
        // The engine runs as root: the folders the app writes into are handed
        // to the app, so a root-owned folder cannot refuse its files.
        ChrootRuntime.ensureAppFolders(rootfs)
        // In the chroot the pid file lives in the tree the app owns: /tmp is a
        // root-owned tmpfs, and the app cannot delete a file it does not own.
        val pidFile = File(rootfs, "root/.dsh/dsh-app/dsh-web.pid")
        pidFile.delete() // also removes a stale/dangling symlink; never reuse a previous run's PID
        check(!java.nio.file.Files.exists(pidFile.toPath(), java.nio.file.LinkOption.NOFOLLOW_LINKS)) { "cannot remove stale runtime pid file" }
        port = pickPort()
        val tmp = File(context.cacheDir, "chroot-tmp").apply { mkdirs() }
        val vars = mapOf(
            "{CHROOT}" to rootfs.canonicalPath,
            "{ROOTFS}" to rootfs.canonicalPath,
            "{TMP}" to tmp.absolutePath,
            "{FILES_DIR}" to context.filesDir.absolutePath,
            "{PORT}" to port.toString(),
        )
        fun expand(s: String) = vars.entries.fold(s) { acc, (k, v) -> acc.replace(k, v) }

        val argv = ArrayList<String>()
        val launchArgv = manifest.launchArgv
        val effectiveGuestEnv = guestEnv + ("DSH_GO_RUNTIME_ROOT" to rootfs.canonicalPath)
        var guestEnvPlaced = false
        check(manifest.launchArgv.isNotEmpty()) { "runtime manifest has no launch.argv" }
        var profileSelected = false
        // Only overlays successfully prepared for this launch; cleanup may leave an old file behind.
        // Also require the file in place (a missing --patch file stops DSH).
        var searchPending = !safe && searchOverlay && SessionSearchGuest.file(rootfs).isFile
        // Subscription sign-in: the same rule for the auth bridge overlay.
        var authPending = !safe && authOverlay && AppAuthGuest.file(rootfs).isFile
        // On-device voice input: the recognizer's phone settings, same rule.
        var speechPending = !safe && speechOverlay && SpeechGuest.file(rootfs).isFile
        for (arg in launchArgv) {
            if (arg == GUEST_ENV) {
                effectiveGuestEnv.forEach { (k, v) -> argv += "$k=$v" }
                guestEnvPlaced = true
            } else {
                val selected = SafeMode.profileArg(arg, safe)
                if (selected != null) profileSelected = true
                // Phone control: add its --patch overlay to `dsh web` (never in safe mode).
                val withPhone = if (phone && !safe && !phoneMounted) PhoneGuest.launchArg(selected ?: arg) else null
                if (withPhone != null) phoneMounted = true
                val withSearch = if (searchPending) SessionSearchGuest.launchArg(withPhone ?: selected ?: arg) else null
                if (withSearch != null) searchPending = false
                val withAuth = if (authPending) AppAuthGuest.launchArg(withSearch ?: withPhone ?: selected ?: arg) else null
                if (withAuth != null) authPending = false
                val withSpeech = if (speechPending) SpeechGuest.launchArg(withAuth ?: withSearch ?: withPhone ?: selected ?: arg) else null
                if (withSpeech != null) speechPending = false
                argv += expand(withSpeech ?: withAuth ?: withSearch ?: withPhone ?: selected ?: arg)
            }
        }
        check(!safe || profileSelected) { "safe mode: this runtime's launch command has no `dsh web` to replace" }

        if (!guestEnvPlaced) {
            // No {GUEST_ENV} slot in the template: the whole environment is ours.
            argv += effectiveGuestEnv.entries.map { (k, v) -> "$k=$v" }
        }
        // The guest command runs from a script inside the chroot: no quoting
        // problems with the engine's own arguments.
        val script = ChrootRuntime.launchScript(argv.map { expand(it) }, emptyMap(), port)
        val scriptFile = File(rootfs, ChrootRuntime.LAUNCH_SCRIPT.removePrefix("/"))
        scriptFile.parentFile?.mkdirs()
        scriptFile.writeText(script)
        scriptFile.setExecutable(true)

        val phoneStorageMount = binds.any { it == "/storage" || it.endsWith(":/sdcard") }
        val builder = ProcessBuilder(ChrootRuntime.launchCommand(context, phoneStorageMount)).directory(context.filesDir)
        val env = builder.environment()
        env.clear()
        env["PATH"] = "/system/bin:/system/xbin"
        env["HOME"] = context.filesDir.absolutePath
        env["TMPDIR"] = tmp.absolutePath
        env["ANDROID_ROOT"] = System.getenv("ANDROID_ROOT") ?: "/system"
        env["ANDROID_DATA"] = System.getenv("ANDROID_DATA") ?: "/data"

        readyReported = false
        listener.onLog("[dsh-app] launch method: chroot (${ChrootRuntime.ROOT})", "system")
        listener.onLog("[dsh-app] launching ${builder.command().joinToString(" ") { redact(it) }}", "system")
        // stop() came in while this was being prepared: don't launch at all.
        if (stopping) {
            listener.onExit(this, 0, true)
            return
        }
        onLaunchMethod?.invoke(direct)
        val p = builder.start()
        process = p
        launchDiagnostics.spawned()
        val out = pump(p.inputStream.bufferedReader(), "stdout")
        val err = pump(p.errorStream.bufferedReader(), "stderr")
        // The engine's own output lands in a file (the app may be frozen); tail it
        // for the token and for the log view.
        tailEngineLog()
        waiter = thread(name = "dsh-wait", isDaemon = true) {
            val code = try { p.waitFor() } catch (_: InterruptedException) { -1 }
            startupSignal.countDown()
            // The fatal message is usually the last output: let the pumps drain it before reporting.
            try {
                out.join(2000)
                err.join(2000)
            } catch (_: InterruptedException) {
            }
            // Report after a running stop() has finished: its killStrays() must not hit the next launch.
            val stopThread = synchronized(this) {
                process = null
                stopper
            }
            stopThread?.join()
            // An unexpected parent exit can leave tracees behind too. Keep the
            // controller's ownership until this UID sweep has finished.
            if (stopThread == null) killStrays()
            listener.onExit(this, code, expectedExit)
        }
        // The port deadline starts only after a token. A stuck loader/Node can emit nothing.
        thread(name = "dsh-start-deadline", isDaemon = true) {
            if (startupSignal.await(TOKEN_TIMEOUT_MS, TimeUnit.MILLISECONDS)) return@thread
            synchronized(this) {
                // Token detection and stop share this lock; a late deadline cannot retire either.
                if (process === p && p.isAlive && !readyReported && !stopping) {
                    startupTokenTimedOut = true
                    failStart("no startup token received within ${TOKEN_TIMEOUT_MS / 1000}s")
                }
            }
        }
        if (stopping) stop()
    }

    private fun tidyLinks(binds: List<String>): DirectLaunch.Selection {
        val started = System.nanoTime()
        // Every bind a PRoot launch may have used: this one's, plus the rootfs alias of earlier ones.
        val guestBinds = L2sMigration.bindTargets(
            DirectLaunch.prootArguments(rootfs, manifest.launchArgv, direct = false),
            binds + DirectLaunch.samePathBind(rootfs),
        )
        val result = try {
            L2sMigration(rootfs, ::syncFilesystems, guestBinds = guestBinds).run(onSlow = { listener.onTidying(true) })
        } catch (e: Exception) {
            listener.onLog("[dsh-app] direct fallback: tidying PRoot links stopped (${e.javaClass.simpleName}: ${e.message}); compatible launch this time, the next start continues", "system")
            return DirectLaunch.Selection(false, DirectLaunch.MIGRATION_FAILED)
        } finally {
            listener.onTidying(false)
        }
        if (result is L2sMigration.Result.NotEnoughSpace) {
            listener.onLog("[dsh-app] direct fallback: tidying PRoot links needs ${result.need shr 20} MB plus ${L2sMigration.MARGIN shr 20} MB spare, ${result.free shr 20} MB free; compatible launch this time", "system")
            return DirectLaunch.Selection(false, DirectLaunch.NOT_ENOUGH_SPACE)
        }
        listener.onLog("[dsh-app] direct: moved ${(result as L2sMigration.Result.Done).links} PRoot links to real files in ${(System.nanoTime() - started) / 1_000_000} ms", "system")
        val reason = DirectLaunch.compatibilityReason(rootfs)
        return DirectLaunch.Selection(reason == null, reason)
    }

    /** Waits for cleanup and exit reporting; zero waits until completion. */
    fun awaitExit(millis: Long = 0): Boolean {
        // The waiter joins the stopper before reporting exit. Startup can fail
        // after spawning but before allocating it, so await the stopper then.
        val ending = waiter ?: stopper
        ending?.join(millis)
        return ending?.isAlive != true
    }

    /** Preserve a startup failure through cleanup and the service's later STOP. */
    @Synchronized fun failStart(message: String) {
        if (stopping) {
            // STOP may have preceded spawn, then setup failed before start's final stop().
            // Preserve its expected-exit/error facts while cleaning any process now present.
            stop(expected = false)
            return
        }
        startupError = message
        listener.onLog("[dsh-app] start failed: $message", "system")
        listener.onStartupFailure(this)
        stop(expected = false)
    }

    /**
     * proot ignores SIGTERM, so stop DSH itself first (pid file written by the launch
     * command), then SIGQUIT proot, which kills every remaining tracee.
     */
    @Synchronized fun stop(expected: Boolean = true) {
        stopping = true
        startupSignal.countDown()
        if (expected) expectedExit = true
        if (stopper != null) return
        val p = process ?: return
        stopper = thread(name = "dsh-stop", isDaemon = true) {
            try {
                val node = if (p.isAlive) guestRecord() else null
                val pid = guestPid()
                if (pid != null) signalEngine(pid, OsConstants.SIGTERM)
                else if (node != null) signalOwned(node, OsConstants.SIGTERM)
                else if (p.isAlive) p.destroy() // the engine may fail before writing its pid file
                if (!waitExit(p, 5000)) {
                    // Still running: end it as root (the engine runs as root in the chroot).
                    guestPid()?.let { signalEngine(it, OsConstants.SIGKILL) }
                    p.destroyForcibly()
                }
                waitExit(p, 2000)
            } finally {
                try {
                    if (p.isAlive) p.destroyForcibly()
                } finally {
                    // Reap tracees before waiting: an OEM Process.waitFor may not
                    // return until they exit. The waiter still retains this owner.
                    killStrays()
                    p.waitFor()
                }
            }
        }
    }


    /** The engine's pid, from the chroot's own pid file (always visible). */
    private fun guestPid(): Int? =
        (File(rootfs, "root/.dsh/dsh-app/dsh-web.pid").takeIf { it.isFile }?.readText()
            ?: File(rootfs, "tmp/dsh-web.pid").takeIf { it.isFile }?.readText())
            ?.trim()?.toIntOrNull()

    /**
     * Signals the engine. It runs as root inside the chroot, so the app cannot
     * signal it directly: the signal goes through root when the direct one is
     * refused.
     */
    private fun signalEngine(pid: Int, signal: Int) {
        if (runCatching { Os.kill(pid, signal) }.isSuccess) return
        val su = ChrootRuntime.suBinary() ?: return
        val name = when (signal) {
            OsConstants.SIGKILL -> "KILL"
            OsConstants.SIGQUIT -> "QUIT"
            else -> "TERM"
        }
        runCatching { runRootCommand(su, "kill -$name $pid 2>/dev/null || true", 20_000) }
    }

    private fun waitExit(p: Process, millis: Long): Boolean {
        val deadline = System.nanoTime() + millis * 1_000_000L
        while (p.isAlive && System.nanoTime() < deadline) Thread.sleep(100)
        return !p.isAlive
    }

    /** Guest `dsh web` identity, retained through the final pre-signal PID-reuse check. */
    @Synchronized private fun guestRecord(): RuntimeProcessRecord? = synchronized(cleanupState) {
        captureGuestRecord()
    }

    private fun captureGuestRecord(): RuntimeProcessRecord? {
        return try {
            val pid = (File(rootfs, "root/.dsh/dsh-app/dsh-web.pid").takeIf { it.isFile }?.readText()
                ?: File(rootfs, "tmp/dsh-web.pid").takeIf { it.isFile }?.readText())
                ?.trim()?.toIntOrNull() ?: return null
            val records = processSnapshot().records
            val owned = RuntimeProcessOwnership.owned(records, setOf(rootfs.absolutePath, rootfs.canonicalPath), AndroidProcess.myPid())
            owned.forEach { cleanupKnown[it.pid] = it.started }
            val record = owned.firstOrNull { it.pid == pid } ?: return null
            if (record.argv.any { it.contains("/opt/node") || it.contains("dsh") }) record else null
        } catch (_: Exception) {
            null
        }
    }

    private fun signalOwned(record: RuntimeProcessRecord, value: Int) {
        val current = RuntimeProcessOwnership.stat(File("/proc/${record.pid}/stat").readText())
        // The pid was reused by another process: never signal it.
        if (current?.second != record.started) return
        // The engine runs as root inside the chroot, so the app cannot signal
        // it directly; the signal goes through root instead.
        signalEngine(record.pid, value)
    }


    /**
     * The engine's endpoint, read from its own log.
     *
     * The log holds the token line of the run that is serving now; the last
     * one in it is this engine's. The app asks for it again when a connection
     * fails, so a token from an earlier run cannot keep the app out.
     *
     * @return the base URL and the token, or null when the engine wrote none.
     */
    fun currentEndpoint(): Pair<String, String>? {
        val file = File(rootfs, "root/.dsh/dsh-app/dsh-web.log")
        if (!file.isFile) return null
        var found: Pair<String, String>? = null
        try {
            file.forEachLine { line ->
                val match = TOKEN_URL.find(line) ?: return@forEachLine
                val url = match.value
                val port = TOKEN_PORT.find(url)?.groupValues?.get(1)?.toIntOrNull() ?: return@forEachLine
                val token = TOKEN_PARAM.find(url)?.groupValues?.get(1) ?: return@forEachLine
                found = "http://127.0.0.1:$port" to token
            }
        } catch (_: Exception) {
        }
        return found
    }

    /**
     * Tails the engine's log file: the token line and the runtime log the app
     * shows come from there, so a frozen app never blocks the engine.
     */
    private fun tailEngineLog() = thread(name = "dsh-engine-log", isDaemon = true) {
        val file = File(rootfs, "root/.dsh/dsh-app/dsh-web.log")
        var seen = 0L
        while (!stopping) {
            try {
                if (file.isFile) {
                    val length = file.length()
                    if (length < seen) seen = 0
                    if (length > seen) {
                        val chunk = java.io.RandomAccessFile(file, "r").use { raf ->
                            raf.seek(seen)
                            val bytes = ByteArray((length - seen).coerceAtMost(64 * 1024).toInt())
                            val read = raf.read(bytes)
                            if (read <= 0) "" else String(bytes, 0, read)
                        }
                        seen += chunk.toByteArray().size
                        for (line in chunk.split("\n")) {
                            if (line.isEmpty()) continue
                            listener.onLog(line, "stdout")
                            if (!readyReported) detectToken(line)
                        }
                    }
                }
            } catch (_: Exception) {
            }
            try {
                Thread.sleep(250)
            } catch (_: InterruptedException) {
                return@thread
            }
        }
    }

    private fun pump(reader: java.io.BufferedReader, stream: String) = thread(name = "dsh-$stream", isDaemon = true) {
        try {
            reader.useLines { lines ->
                lines.forEach { line ->
                    listener.onLog(line, stream)
                    if (!readyReported) detectToken(line)
                }
            }
        } catch (_: Exception) {
        }
    }

    @Synchronized private fun detectToken(line: String) {
        if (readyReported || stopping) return
        val match = TOKEN_URL.find(line) ?: return
        val url = match.value
        // Only this run's line: a token from an earlier run names that run's
        // port, and the engine would refuse every request with it.
        val urlPort = TOKEN_PORT.find(url)?.groupValues?.get(1)?.toIntOrNull()
        if (urlPort != null && urlPort != port) return
        val token = TOKEN_PARAM.find(url)?.groupValues?.get(1) ?: return
        readyReported = true
        startupSignal.countDown()
        val base = "http://127.0.0.1:$port"
        thread(name = "dsh-ready", isDaemon = true) {
            val deadline = System.currentTimeMillis() + 90_000
            while (System.currentTimeMillis() < deadline && !stopping && process?.isAlive == true) {
                if (canConnect(port)) {
                    listener.onReady(this, base, token)
                    return@thread
                }
                Thread.sleep(250)
            }
            if (!stopping && process?.isAlive == true) {
                failStart("token seen but port $port never accepted connections")
            }
        }
    }

    /** Reads only this app's uid. Environment values are used for ownership, never logged. */
    private val processReader = object : RuntimeProcessReader {
        override fun pids(): List<Int> = (File("/proc").listFiles() ?: throw IOException("cannot enumerate /proc"))
            .mapNotNull { it.name.toIntOrNull() }
        override fun uid(pid: Int): Int? = try {
            Os.stat("/proc/$pid").st_uid
        } catch (error: ErrnoException) {
            if (error.errno == OsConstants.ENOENT || error.errno == OsConstants.ESRCH) null else throw error
        } catch (_: NoSuchFileException) { null }
        private fun text(pid: Int, name: String): String = Files.readAllBytes(File("/proc/$pid/$name").toPath()).toString(Charsets.UTF_8)
        override fun stat(pid: Int): String = text(pid, "stat")
        override fun command(pid: Int): String = text(pid, "cmdline")
        override fun environment(pid: Int): String = text(pid, "environ")
        override fun cwd(pid: Int): String = Os.readlink("/proc/$pid/cwd")
    }

    private fun processSnapshot(known: Set<Int> = emptySet()): RuntimeProcessSnapshot =
        RuntimeProcessOwnership.scan(processReader, AndroidProcess.myUid(), AndroidProcess.myPid(), known)

    private fun pidHint(): Int? = try {
        File(rootfs, "tmp/dsh-web.pid").readText().trim().toIntOrNull()?.takeIf { it > 0 }
    } catch (_: Exception) { null }

    private fun remember(snapshot: RuntimeProcessSnapshot) {
        snapshot.retired.forEach { cleanupKnown.remove(it) }
        for (record in snapshot.records) {
            if (cleanupKnown[record.pid]?.let { it != record.started } == true) cleanupKnown.remove(record.pid)
        }
    }

    /** Reap a captured process tree before releasing #17 ownership to another launch. */
    @Synchronized fun killStrays(): Boolean = reapStrays().complete

    internal data class CleanupResult(val complete: Boolean, val ownedRemaining: Boolean, val canPruneTemp: Boolean = false)

    /** Unknown ambient processes are not proof of ownership. The default-mode
     * startup policy may continue after reaping every captured identity, while
     * killStrays itself still reports the observation as incomplete. */
    @Synchronized internal fun reapStrays(allowObservationGap: Boolean = false): CleanupResult = synchronized(cleanupState) {
        reapStraysLocked(allowObservationGap)
    }

    private fun reapStraysLocked(allowObservationGap: Boolean): CleanupResult {
        val myPid = AndroidProcess.myPid()
        val roots = setOf(rootfs.absolutePath, rootfs.canonicalPath)
        val hinted = pidHint()?.let { setOf(it) }.orEmpty()
        val deadline = System.nanoTime() + 2_000_000_000L
        var first = true
        while (true) {
            val snapshot = processSnapshot(cleanupKnown.keys + hinted)
            remember(snapshot)
            val owned = RuntimeProcessOwnership.owned(snapshot.records, roots, myPid, cleanupKnown)
            owned.forEach { cleanupKnown[it.pid] = it.started }
            val ownedRemaining = owned.isNotEmpty() || cleanupKnown.isNotEmpty()
            if (!ownedRemaining && snapshot.observed) {
                // This cache is shared across rootfs instances. Another engine may still use its glue.
                val temp = File(context.cacheDir, "proot-tmp").absolutePath
                val idle = snapshot.records.none { it.proot || it.marker != null || RuntimeProcessOwnership.within(it.cwd, temp) }
                return CleanupResult(true, false, canPruneTemp = idle)
            }
            owned.filter { it.proot }.forEach { signalOwned(it, if (first) OsConstants.SIGQUIT else OsConstants.SIGKILL) }
            owned.filterNot { it.proot }.forEach { signalOwned(it, OsConstants.SIGKILL) }
            first = false
            if ((!ownedRemaining && allowObservationGap) || System.nanoTime() >= deadline) {
                listener.onLog("[dsh-app] cleanup incomplete: ${owned.size} owned process(es) remain; " +
                    "${snapshot.uncertain.size} process observation(s) unavailable" +
                    if (snapshot.enumerationFailed) "; /proc enumeration unavailable" else "", "system")
                return CleanupResult(false, ownedRemaining)
            }
            Thread.sleep(25)
        }
    }

    private fun redact(arg: String): String {
        val eq = arg.indexOf('=')
        if (eq <= 0) return arg
        val key = arg.substring(0, eq)
        return if (SECRET_KEY.containsMatchIn(key)) "$key=***" else arg
    }

    companion object {
        const val DEFAULT_PORT = 3080
        const val GUEST_ENV = "{GUEST_ENV}"
        // Bootstrap budget (not a device measurement); token-to-port retains its own 90 seconds.
        private const val TOKEN_TIMEOUT_MS = 180_000L
        private val TOKEN_URL = Regex("""https?://[^\s'"]*[?&#]token=[A-Za-z0-9._~%-]+""")
        private val TOKEN_PARAM = Regex("""[?&#]token=([A-Za-z0-9._~%-]+)""")
        private val TOKEN_PORT = Regex("""://[^/]*?:(\d+)""")
        private val SECRET_KEY = Regex("(?i)(key|token|secret|password)")

        fun canConnect(port: Int): Boolean = try {
            Socket().use { it.connect(InetSocketAddress("127.0.0.1", port), 500); true }
        } catch (_: Exception) {
            false
        }

        fun pickPort(): Int {
            for (candidate in DEFAULT_PORT..DEFAULT_PORT + 20) {
                try {
                    ServerSocket(candidate, 1, InetAddress.getByName("127.0.0.1")).close()
                    return candidate
                } catch (_: Exception) {
                }
            }
            return ServerSocket(0, 1, InetAddress.getByName("127.0.0.1")).use { it.localPort }
        }
    }
}

/** One sync(2): finished copies and renames are on disk before anything depends on them. */
internal fun syncFilesystems() {
    val sync = ProcessBuilder("/system/bin/sync").redirectErrorStream(true).start()
    sync.inputStream.use { it.readBytes() }
    val code = sync.waitFor()
    if (code != 0) throw IOException("sync exited with $code")
}
