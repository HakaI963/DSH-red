package dev.nolyf.dsh_red.runtime

import java.io.File

/**
 * The engine's Linux root, as a real chroot on the phone's own filesystem.
 *
 * DSH red runs the engine without PRoot: the bundled Ubuntu userland is
 * unpacked into [ROOT], the phone's userspace is bind mounted into it, and
 * `chroot` starts the engine as root. That is a plain Linux userland — no
 * ptrace, no ELF translation — so it is much faster than PRoot.
 *
 * It needs root on the phone (Magisk's `su`): without it the engine cannot
 * run at all, and the app says so instead of failing silently.
 */
object ChrootRuntime {
    /** Where the root lives on the phone. */
    const val ROOT = "/data/local/DSH-red/chroot"

    /** The launch script inside the chroot (the app writes it before each start). */
    const val LAUNCH_SCRIPT = "/root/.dsh/dsh-app/launch.sh"

    /** Where the app's own copy of the rootfs waits until it is copied into place. */
    const val STAGING = "/data/local/DSH-red/staging"

    /** The tree this app owns, with the chroot inside it. */
    private const val TREE = "/data/local/DSH-red"

    /** Where the live home waits while the tree is rebuilt. */
    const val CARRY = "$TREE/home.carry"

    /**
     * A tmpfs is created with mode 0755, so every process that is not root
     * was denied its own temp folder inside the chroot (the tools and the
     * spill files live there). A normal Linux /tmp is 1777.
     */
    private const val TMPFS_MODE = "mode=1777"

    /**
     * Hands the tree to this app's uid when the last install had another one.
     *
     * Android gives an app a new uid when it is uninstalled and installed
     * again. The tree under /data/local keeps the old owner, and the app can
     * then write nothing into it any more — not even its own launch script.
     * Root repairs the ownership once per uid change; the marker says which
     * uid owns the tree now.
     *
     * @return true when the tree had to be handed over.
     */
    fun ensureTreeOwnership(): Boolean {
        val su = suBinary() ?: return false
        val uid = android.os.Process.myUid()
        val script = """
            marker='$ROOT/root/.dsh/dsh-app/owner'
            current=`cat "${'$'}marker" 2>/dev/null`
            if [ "${'$'}current" = "$uid" ]; then echo owned; exit 0; fi
            chown -R $uid:$uid '$TREE' 2>/dev/null
            mkdir -p '$ROOT/root/.dsh/dsh-app' 2>/dev/null || true
            echo "$uid" > "${'$'}marker" 2>/dev/null || true
            echo reowned
        """.trimIndent()
        val out = runCatching { runRootCommand(su, script, 600_000) }.getOrDefault("")
        return out.contains("reowned")
    }

    /**
     * Hands the app's own folders in the tree to this app's uid.
     *
     * The engine runs as root and creates what it needs there (its home, the
     * app's folder inside it, the workspace). A folder that root created
     * cannot be written by the app, and the app's launch script lives in one
     * of them.
     */
    fun ensureAppFolders(rootfs: File): Boolean {
        val su = suBinary() ?: return false
        val uid = android.os.Process.myUid()
        val script = """
            for d in '${rootfs.path}/root/.dsh' '${rootfs.path}/root/.dsh/dsh-app' '${rootfs.path}/root/workspace' '${rootfs.path}/etc'; do
              [ -d "${'$'}d" ] && chown $uid:$uid "${'$'}d" 2>/dev/null
            done
            echo done
        """.trimIndent()
        return runCatching { runRootCommand(su, script, 60_000) }.isSuccess
    }

    /**
     * Hands one path of the tree to this app's uid.
     *
     * The fallback for a write that was refused: the folder still belongs to
     * an earlier install of this app.
     */
    fun chownToApp(path: File): Boolean {
        val su = suBinary() ?: return false
        val uid = android.os.Process.myUid()
        val script = "chown -R $uid:$uid '${path.absolutePath}' 2>/dev/null; echo done"
        return runCatching { runRootCommand(su, script, 120_000) }.isSuccess
    }

    private val suCandidates = listOf(
        "/system/xbin/su",
        "/system/bin/su",
        "/sbin/su",
        "/debug_ramdisk/su",
        "/sbin/.magisk/su",
        "/system/sbin/su",
        "/vendor/bin/su",
    )

    /** The `su` binary on this phone, null when the phone is not rooted. */
    fun suBinary(): String? =
        suCandidates.firstOrNull { File(it).canExecute() }
            ?: listOf("/system/xbin", "/system/bin", "/sbin", "/debug_ramdisk")
                .firstOrNull { dir -> File(dir, "su").canExecute() }
                ?.let { File(it, "su").absolutePath }

    /** Whether `su` really hands out root here. */
    fun rootAvailable(): Boolean {
        val su = suBinary() ?: return false
        return runCatching { runRoot(su, "id", 20_000).contains("uid=0") }.getOrDefault(false)
    }

    /** Runs [command] as root and returns its combined output. */
    fun runRoot(su: String, command: String, timeoutMs: Long = 600_000): String = runRootCommand(su, command, timeoutMs)

    /** Runs [command] as root, or throws a message the app can show. */
    fun root(command: String, timeoutMs: Long = 600_000): String {
        val su = suBinary() ?: throw IllegalStateException("no root on this phone: the engine needs a rooted device (Magisk) to run in a chroot")
        return runRootCommand(su, command, timeoutMs)
    }

    /**
     * Copies the freshly unpacked rootfs into the chroot and hands the tree to
     * the app's own uid, so the overlays the app writes (the DSH patch files,
     * the phone-control guest files) land in the live root without root.
     */
    fun install(stagedRoot: File, uid: Int, gid: Int, onLog: (String) -> Unit) {
        val source = stagedRoot.canonicalPath
        onLog("[dsh-app] chroot: copying the runtime into $ROOT (this takes a few minutes the first time)")
        root("set -e; rm -rf '$ROOT' '$STAGING'; mkdir -p '$ROOT'; cp -a '$source/.' '$ROOT/'; chown -R $uid:$gid '$ROOT'")
        onLog("[dsh-app] chroot: runtime copied")
    }

    /** Whether the chroot already holds this runtime version. */
    fun installedVersion(): String? {
        val marker = File(ROOT, "root/.dsh/dsh-app/runtime-version")
        return if (marker.isFile) marker.readText().trim().ifEmpty { null } else null
    }

    /** Records the runtime version inside the chroot (the app owns the tree). */
    fun writeVersion(version: String) {
        val marker = File(ROOT, "root/.dsh/dsh-app/runtime-version")
        marker.parentFile?.mkdirs()
        marker.writeText(version)
    }

    /**
     * The mounts the chroot needs, from the person's list (prefs): the phone's
     * own kernels interfaces, its userspace (/data, /storage, /sdcard) and
     * whatever they added. Off mounts are left out; "ask each time" mounts go
     * in read-only until the person allows them.
     */
    fun mountScript(context: android.content.Context, phoneStorage: Boolean): String {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.chroot_mounts", null)
        // Without a saved list the phone's storage is mounted only when the
        // person granted access to it (as before, under PRoot).
        // The person's list wins, but the phone's storage follows the grant:
        // a list saved before the grant existed must not hide it.
        val mounts = if (raw.isNullOrEmpty()) defaultMounts(phoneStorage) else parseMounts(raw).let { saved ->
            if (!phoneStorage) saved
            else saved.map { if (it.target == "/sdcard" || it.target == "/storage") it.copy(enabled = true) else it }
        }
        val lines = mutableListOf("set -e")
        for (mount in mounts) {
            if (!mount.enabled) continue
            val target = "${ROOT}${mount.target}"
            val readOnly = mount.access != "readWrite"
            // The mount point must exist: the rootfs has no /sdcard or /storage.
            lines += "mkdir -p $target 2>/dev/null || true"
            lines += when (mount.source) {
                "proc" -> "mount -t proc proc $target 2>/dev/null || true"
                "sysfs" -> "mount -t sysfs -o ro,nosuid,nodev sysfs $target 2>/dev/null || true"
                "tmpfs" -> {
                    val size = if (mount.target.endsWith("shm")) "64m" else "512m"
                    "mount -t tmpfs -o size=$size,$TMPFS_MODE tmpfs $target 2>/dev/null || true"
                }
                else -> {
                    val ro = if (readOnly) "-o ro" else ""
                    // --rbind: /dev/pts (the terminal's pty) and /storage/emulated
                    // (sdcardfs) are separate mounts; a plain bind leaves them empty.
                    "mount --rbind $ro ${mount.source} $target 2>/dev/null || true; " +
                        "mount --make-rslave $target 2>/dev/null || true"
                }
            }
        }
        lines += "mkdir -p ${ROOT}/root/.dsh/dsh-app 2>/dev/null || true"
        // The engine runs as root, so the files it leaves in the app's own
        // folder (the log, the pid file) belong to root and the app could not
        // replace them. The app owns this folder.
        lines += "chown -R ${android.os.Process.myUid()}:${android.os.Process.myUid()} ${ROOT}/root/.dsh/dsh-app 2>/dev/null || true"
        return lines.joinToString("\n") + "\n"
    }

    /** One mount from the prefs JSON. */
    data class Mount(val source: String, val target: String, val enabled: Boolean, val access: String) {
        fun copy(enabled: Boolean = this.enabled) = Mount(source, target, enabled, access)
    }

    /** Reads the person's mount list; the built-in default when there is none. */
    fun parseMounts(raw: String?): List<Mount> {
        if (raw.isNullOrEmpty()) return defaultMounts(false)
        return try {
            val array = org.json.JSONArray(raw)
            val out = mutableListOf<Mount>()
            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                out += Mount(
                    source = item.optString("source"),
                    target = item.optString("target"),
                    enabled = item.optBoolean("enabled", true),
                    access = item.optString("access", "readOnly"),
                )
            }
            if (out.isEmpty()) defaultMounts(false) else out
        } catch (_: Exception) {
            defaultMounts(false)
        }
    }

    /** The mounts the chroot starts with (the Dart side's defaults). */
    fun defaultMounts(phoneStorage: Boolean): List<Mount> = listOf(
        Mount("/sdcard", "/sdcard", phoneStorage, "readWrite"),
        Mount("/storage", "/storage", phoneStorage, "readWrite"),
        Mount("/data", "/data", true, "readWrite"),
        Mount("/system", "/system", true, "readOnly"),
        Mount("/apex", "/apex", true, "readOnly"),
        Mount("/mnt/user", "/mnt/user", true, "readOnly"),
        Mount("proc", "/proc", true, "readOnly"),
        Mount("sysfs", "/sys", true, "readOnly"),
        Mount("/dev", "/dev", true, "readOnly"),
        Mount("tmpfs", "/tmp", true, "readWrite"),
        Mount("tmpfs", "/dev/shm", true, "readWrite"),
    )


    /**
     * The command that starts the engine inside the chroot. The mounts are
     * part of it, so the phone is asked for root once per start.
     */
    fun launchCommand(context: android.content.Context, phoneStorage: Boolean): List<String> {
        val su = suBinary() ?: throw IllegalStateException("no root on this phone: the engine needs a rooted device (Magisk) to run in a chroot")
        val script = "exec chroot '$ROOT' /bin/sh '$LAUNCH_SCRIPT'"
        return listOf(su, "-c", mountScript(context, phoneStorage) + script)
    }

    /**
     * Mounts or unmounts the phone's shared storage in the running chroot: the
     * engine asks for it while it runs, and the mount list is fixed at launch.
     */
    fun setPhoneStorageMounted(enabled: Boolean): Boolean {
        val su = suBinary() ?: return false
        val command = if (enabled) {
            "mkdir -p '$ROOT/sdcard' '$ROOT/storage' 2>/dev/null || true; " +
                "mount --rbind /sdcard '$ROOT/sdcard' 2>/dev/null || true; " +
                "mount --make-rslave '$ROOT/sdcard' 2>/dev/null || true; " +
                "mount --rbind /storage '$ROOT/storage' 2>/dev/null || true; " +
                "mount --make-rslave '$ROOT/storage' 2>/dev/null || true; true"
        } else {
            "umount '$ROOT/sdcard' 2>/dev/null || true; umount '$ROOT/storage' 2>/dev/null || true; true"
        }
        return runCatching { runRootCommand(su, command, 60_000) }.isSuccess
    }

    /** Single-quotes [value] for the shell. */
    fun shellQuote(value: String): String = "'" + value.replace("'", "'\\''") + "'"

    /**
     * Ends every engine left over from an earlier run.
     *
     * In the chroot the engine runs as root: the app cannot signal it and
     * cannot even read its /proc entries, so a leftover survives every cleanup
     * the app can do on its own. It keeps the write lock of the chats it had
     * open ("this chat is in use elsewhere"), and a second engine starts next
     * to it. Only a process that runs from this chroot is touched.
     *
     * @return how many processes were asked to stop.
     */
    fun killLeftoverEngines(): Int {
        val su = suBinary() ?: return 0
        val script = """
            ended=0
            for p in /proc/[0-9]*; do
              pid=${'$'}{p#/proc/}
              exe=`readlink "${'$'}p/exe" 2>/dev/null` || continue
              case "${'$'}exe" in
                "$ROOT"/*) kill -TERM "${'$'}pid" 2>/dev/null && ended=${'$'}((ended+1)) ;;
              esac
            done
            sleep 1
            for p in /proc/[0-9]*; do
              pid=${'$'}{p#/proc/}
              exe=`readlink "${'$'}p/exe" 2>/dev/null` || continue
              case "${'$'}exe" in
                "$ROOT"/*) kill -KILL "${'$'}pid" 2>/dev/null ;;
              esac
            done
            echo "ended ${'$'}ended"
        """.trimIndent()
        val out = runCatching { runRootCommand(su, script, 60_000) }.getOrDefault("")
        return Regex("ended (\\d+)").find(out)?.groupValues?.get(1)?.toIntOrNull() ?: 0
    }

    /**
     * The launch script: the guest command from the runtime manifest with the
     * app's own environment added, run under `env -i` inside the chroot.
     */
    fun launchScript(guestArgv: List<String>, guestEnv: Map<String, String>, port: Int): String {
        val parts = mutableListOf<String>()
        var i = 0
        while (i < guestArgv.size) {
            val arg = guestArgv[i]
            when {
                arg == "{GUEST_ENV}" -> {
                    parts += guestEnv.entries.map { (k, v) -> shellQuote("$k=$v") }
                    i++
                }
                arg == "/bin/sh" && i + 1 < guestArgv.size && guestArgv[i + 1] == "-c" && i + 2 < guestArgv.size -> {
                    val command = guestArgv[i + 2].replace("{PORT}", port.toString())
                    parts += "/bin/sh"
                    parts += "-c"
                    parts += shellQuote(command)
                    i += 3
                }
                else -> {
                    parts += shellQuote(arg)
                    i++
                }
            }
        }
        // The pid file in the chroot's own home is always visible to the app;
        // /tmp may be a tmpfs the app cannot see.
        return "#!/bin/sh\necho \$\$ > /root/.dsh/dsh-app/dsh-web.pid\n" +
            "# The engine's own output goes to a file: the app may be frozen or gone,\n" +
            "# and a pipe it stops reading would block (or kill) the engine.\n" +
            "exec " + parts.joinToString(" ") + " >> /root/.dsh/dsh-app/dsh-web.log 2>&1\n"
    }
}
