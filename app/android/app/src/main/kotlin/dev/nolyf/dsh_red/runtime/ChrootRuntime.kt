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
    fun runRoot(su: String, command: String, timeoutMs: Long = 600_000): String {
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

    /** Runs [command] as root, or throws a message the app can show. */
    fun root(command: String, timeoutMs: Long = 600_000): String {
        val su = suBinary() ?: throw IllegalStateException("no root on this phone: the engine needs a rooted device (Magisk) to run in a chroot")
        return runRoot(su, command, timeoutMs)
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
     * The mounts the chroot needs: the phone's own kernels interfaces, its
     * userspace (/data, /storage, /sdcard) and a couple of small tmpfs.
     * Everything that is already mounted is left alone, so a restart is cheap.
     */
    fun mountScript(): String = buildString {
        append("set -e\n")
        append("R='$ROOT'\n")
        append("mkdir -p $R/proc $R/sys $R/dev/shm $R/tmp $R/data $R/storage $R/sdcard $R/system $R/apex $R/mnt/user $R/root/.dsh/dsh-app\n")
        append("mount -t proc proc $R/proc 2>/dev/null || true\n")
        append("mount -t sysfs -o ro,nosuid,nodev sysfs $R/sys 2>/dev/null || true\n")
        append("mount --bind /dev $R/dev 2>/dev/null || true\n")
        append("mount -t tmpfs -o size=64m tmpfs $R/dev/shm 2>/dev/null || true\n")
        append("mount -t tmpfs -o size=512m tmpfs $R/tmp 2>/dev/null || true\n")
        append("mount --bind /data $R/data 2>/dev/null || true\n")
        append("mount --bind /storage $R/storage 2>/dev/null || true\n")
        append("mount --bind /sdcard $R/sdcard 2>/dev/null || true\n")
        append("mount --bind /mnt/user $R/mnt/user 2>/dev/null || true\n")
        append("mount --bind -o ro /system $R/system 2>/dev/null || true\n")
        append("mount --bind -o ro /apex $R/apex 2>/dev/null || true\n")
    }

    /** Sets the mounts up; every mount is best-effort (a missing one is logged). */
    fun mount(onLog: (String) -> Unit) {
        val out = runCatching { root(mountScript(), 120_000) }.getOrElse {
            onLog("[dsh-app] chroot: mounts failed: ${it.message}")
            throw it
        }
        if (out.isNotBlank()) onLog("[dsh-app] chroot: $out")
    }

    /** The command that starts the engine inside the chroot. */
    fun launchCommand(): List<String> {
        val su = suBinary() ?: throw IllegalStateException("no root on this phone: the engine needs a rooted device (Magisk) to run in a chroot")
        return listOf(su, "-c", "exec chroot '$ROOT' /bin/sh '$LAUNCH_SCRIPT'")
    }

    /** Single-quotes [value] for the shell. */
    fun shellQuote(value: String): String = "'" + value.replace("'", "'\\''") + "'"

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
        return "#!/bin/sh\nexec " + parts.joinToString(" ") + "\n"
    }
}
