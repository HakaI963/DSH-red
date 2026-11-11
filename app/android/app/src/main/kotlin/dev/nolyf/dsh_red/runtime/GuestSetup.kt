// Portions derived from DS Bot (https://github.com/Fei2411/DeepSeek-Bot), Apache-2.0, Copyright 2026 Fei2411 and the DS Bot contributors. See THIRD_PARTY_NOTICES.md.
// Modified: the `show_view` description and prompt rule (`ds-bot/src/host/tools.js`, `prompt.js`)
// rewritten as English instructions for a ```dsh-ui fenced block in a phone chat.
package dev.nolyf.dsh_red.runtime

import android.content.Context
import android.net.ConnectivityManager
import android.system.ErrnoException
import android.system.Os
import dev.nolyf.dsh_red.phone.PhoneGuest
import java.io.File
import java.io.IOException
import java.net.Inet4Address
import java.net.InetAddress

/** Small files inside the rootfs that must reflect the device before each start. */
object GuestSetup {
    private val FALLBACK_DNS = listOf("223.5.5.5", "119.29.29.29", "8.8.8.8")

    private const val AGENTS_MARKER = "<!-- dsh-app:managed"

    // l10n:keep agent prompt
    private val AGENTS_MD = ("""
        |<!-- dsh-app:managed — if this line is deleted, the DSH App stops overwriting this file -->
        |# Runtime environment (DSH phone edition)
        |
        |- You run in an Ubuntu 24.04 environment on an Android phone (proot, no Root needed). No sandbox backend is available here (neither bubblewrap nor Landlock works), so `workspace-write` sandbox mode will always be denied.
""" +
        // l10n:keep agent prompt
        """        |- Always answer in the language the user writes in; default to English.
        |- When you need a bash command, request it directly with `sandbox_permissions: "danger-full-access"` and state the reason in one sentence; do not try sandbox mode first.
        |- The default working directory is `/root/workspace`. {STORAGE_LINE}
        |- Preinstalled: node / npm / pnpm, python3 / pip, git; npm and pnpm default to registry.npmjs.org. For any other missing tool run `apt-get update && apt-get install -y <package>` (needs network).
        |- The phone screen is small: keep replies concise and don't make code blocks too wide.
        |
        |## Interface and skills
        |
        |- This App's chat UI is a native Flutter interface, not the Harness Web Client. To change the App's own look use dsh-go-ui (ui.json); to add features to the App — capsules, menu items, status bars, native panels, tool cards — use dsh-go-plugin; only use official skills such as cordis-plugin-development when the user explicitly wants a Cordis plugin, or wants to change the Harness web / desktop client.
        |- When the interface carrier isn't named, the default target on the phone is the dsh-go native UI; decide the carrier first, then pick the skill — don't decide by load order.
        |- dsh-go native plugins are not Cordis bundles: the directory is `${'$'}DSH_HOME/dsh-go/plugins/`, install with `dsh plugin --profile web add`; the official skills' "workspace package + plugin_manager install_bundle" flow is only for Cordis plugins — don't mix the two sets.
        |- When the user reports a fault, troubleshoots, or writes a bug report, load the `dsh-go-support` skill: it teaches you how to read local diagnostics, locate issues by symptom, and generate a redacted issue draft.
        |""").trimMargin()

    /**
     * Appended while "Visual replies" is on (default): how to answer with a ```dsh-ui view. The
     * component list and the rules are adapted from DS Bot's `show_view` description and prompt
     * rule (`ds-bot/src/host/tools.js`, `prompt.js`), rewritten for a fenced block in a phone chat.
     */
    // l10n:keep agent prompt
    private val DSH_UI_SECTION = ("""
        |
        |## Visual replies (dsh-ui)
        |
        |- This App can draw code blocks fenced with ```dsh-ui as native charts and cards. Use a view only when it's clearer than text: chart to compare values or see trends, metric for a few key numbers, compare to weigh options against each other, steps for progress, and options or confirm when the user needs to pick. Never for small talk, a single number, or ordinary lists.
        |- Give the conclusion in one or two sentences first, then the view. Don't write the same data once in text, once in a table and once in a chart. At most two views per reply.
        |- It must be a fenced block: one line with only ```dsh-ui, the JSON starting on the next line, and a final line with only ```. Writing the JSON bare in the body stays plain text and renders nothing.
        |- Put exactly one JSON object inside the fence: no comments, no trailing commas, no more than 4 KB. Data must be real; flag example or estimated numbers in the caption.
        |- Components: stack / row {children}; text {text}; metric {label, value, tone?: good|warn|bad, caption?}; chart {kind: bar|hbar|line|donut, categories, series: [{name?, values}], unit?, caption?} (values map one-to-one onto categories, at most 6 series of 60 points each; donut takes a single series); compare {items: [{title, badge?, rows: [[name, value]]}]} (2–4 items); steps {items: [{label, status: done|current|todo|failed, detail?}]}; callout {text, tone?: info|good|warn|bad}; options {id, options: [{label, description?}], multi?, freetext?} (at most 8); confirm {id, confirmLabel?, cancelLabel?}. The root node may carry a title.
        |- To allow answers beyond the fixed choices, add `freetext: true` (it can also be a hint string, e.g. `freetext: "write your own"`): an input box appears below the options, and what the user types comes back together with the choice as "Other: ...".
""" +
        // l10n:keep agent prompt
        """        |- Example:
        |```dsh-ui
        |{"type":"stack","title":"Spending over the last 6 months","children":[{"type":"metric","label":"Monthly average","value":"¥4,180"},{"type":"chart","kind":"bar","categories":["May","Jun"],"series":[{"values":[3800,4100]}],"unit":"yuan"}]}
        |```
""" +
        // l10n:keep agent prompt
        """        |- Put views containing options or confirm at the end of the reply, then end the turn; the user's choice comes back as a message starting with "[dsh-ui reply]" (e.g. "Select: Option A", "Confirm: Start"; anything the user typed comes back on its own line as "Other: ..."). Use ask_user_question for a single simple question.
        |- Don't use views to collect passwords, keys or verification codes.
        |""").trimMargin()

    // l10n:keep agent prompt
    private val DIAGNOSTICS_SECTION = """
        |
        |## Local diagnostics
        |
        |- When the user reports a fault (lag, overheating, can't connect, update failures, crashes, a plugin not taking effect, phone-control failures), read the available diagnostics: right after the user publishes one manually, prefer `diagnostics-manual.md` in the same directory; otherwise read the automatic snapshot `{PATH}` first. Check the report's time, version and device, then analyze engine state, connection mode, performance and the limited logs; when one report is available, don't keep asking for a refresh just because the other is missing, and no need to ask again before reading.
        |- After the user taps "Let the AI read diagnostics", `diagnostics-manual.md` in the same directory keeps the most recent manual report (it may contain IME evidence collected with the user's consent this time); when it exists, read it too and check its capture time. Later automatic snapshots don't overwrite it; only the next manual publish replaces it, and clearing the App's in-memory evidence does not retract an already published file.
        |- When you need more detail, have the user export a diagnostics bundle (zip) under Settings → Diagnostics; it stays subject to the log count and size limits. If the data is insufficient, say so — don't draw conclusions from guesswork.
        |- Reports attempt redaction but omissions can't be guaranteed. Before sending anything out, manually check credentials, paths and device info, and never paste full reports or secrets into chat or issues.
        |- The complete troubleshooting flow (symptom checklist, issue template, privacy red lines) is in the `dsh-go-support` skill; load it before acting when the user reports a fault.
        |""".trimMargin()

    /** Where the engine's agent finds that snapshot, inside the guest. */
    private const val DIAGNOSTICS_FILE = "root/.dsh/dsh-app/diagnostics.md"

    /** Atomically replaces one fixed report and returns its actual host file. */
    fun writeDiagnostics(rootfs: File, markdown: String, safe: Boolean = false, manual: Boolean = false): File {
        val path = if (safe) "${SafeMode.HOME.removePrefix("/")}/dsh-app/diagnostics.md" else DIAGNOSTICS_FILE
        val main = File(rootfs, path)
        val dir = main.parentFile ?: throw IOException("no diagnostics directory")
        if (!dir.isDirectory && !dir.mkdirs()) throw IOException("cannot create ${dir.path}")
        val file = if (manual) File(dir, "diagnostics-manual.md") else main
        val temp = File(dir, ".${file.name}.dsh-tmp")
        try {
            temp.writeText(markdown)
            if (!temp.renameTo(file)) throw IOException("cannot replace ${file.path}")
        } finally {
            temp.delete()
        }
        return file
    }

    /** Global DSH instructions ($DSH_HOME/AGENTS.md); left alone once the user removes the marker. */
    fun writeAgentsMd(
        rootfs: File,
        phoneStorage: Boolean,
        phoneControl: Boolean = false,
        visualReplies: Boolean = true,
        directEngine: Boolean = false,
        executionMode: String = "proot",
        reconnect: String? = null,
    ) {
        try {
            val file = File(rootfs, "root/.dsh/AGENTS.md")
            if (file.exists() && !file.readText().startsWith(AGENTS_MARKER)) return
            val environment = if (directEngine) {
                // l10n:keep agent prompt
                AGENTS_MD.replace("Ubuntu 24.04 environment on an Android phone (proot, no Root needed)", "Ubuntu 24.04 environment started directly by the engine (bash/git/python/apt tools still run through proot)")
                    .replace("`/root/workspace`", "`${rootfs.canonicalPath}/root/workspace`") +
                    "\n- File tools, the session directory, @ references, AGENTS and skills all use the same full absolute path; that path is visible under the same name inside the shell too. The old `/root` paths still work for file tools. Shell output is not rewritten; do not strip a path's prefix.\n"
            } else AGENTS_MD
            val text = environment.replace(
                "{STORAGE_LINE}",
                if (phoneStorage) {
                    // l10n:keep agent prompt
                    "The user has granted access to phone storage: the phone's internal storage is mounted at `/sdcard` (`/root/Phone storage` is a shortcut to it; photos are in `/sdcard/DCIM`, downloads in `/sdcard/Download`). Explain and confirm before modifying or deleting user files; put output files for the user in `/sdcard/Download/DSH-Go/`."
                } else {
                    // l10n:keep agent prompt
                    "The user's photos, downloads and other phone files are not part of this environment and can't be seen; if access is needed, ask the user to turn on \"Access phone files\" in the App settings."
                },
            ) + "\n- Engine execution mode: " + when (executionMode) {
                "shizuku" -> "shizuku (asked for; the engine still runs in the chroot until the Shizuku shell lands)"
                else -> "chroot on this phone's own filesystem (/data/local/DSH-red/chroot), started as root; no PRoot, no translation layer"
            } + ".\n" +
                (if (reconnect != null && reconnect != "off") {
                    val parts = reconnect.split(":").mapNotNull { it.toIntOrNull() }
                    if (parts.size >= 3) "- Model-call retries: the harness retries a failed model call up to ${parts[0]} times, backing off from ${parts[1]} s up to ${parts[2]} s; a turn only stops after those attempts.\n"
                    else "- Model-call retries: enabled.\n"
                } else "- Model-call retries: disabled; a failed model call stops the turn immediately.\n") +
                (if (visualReplies) DSH_UI_SECTION else "") +
                (if (phoneControl) PhoneGuest.AGENTS_SECTION else "") +
                DIAGNOSTICS_SECTION.replace(
                    "{PATH}",
                    if (directEngine) "${rootfs.canonicalPath}/root/.dsh/dsh-app/diagnostics.md"
                    else "\$DSH_HOME/dsh-app/diagnostics.md",
                )
            file.parentFile?.mkdirs()
            if (!file.exists() || file.readText() != text) file.writeText(text)
        } catch (_: Exception) {
        }
    }

    /** glibc in the guest reads /etc/resolv.conf; Android has none, so mirror the active network's DNS. */
    fun writeResolvConf(context: Context, rootfs: File): DnsConfigReport =
        writeResolvConfFromNetwork(rootfs, {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            cm.getLinkProperties(cm.activeNetwork)?.dnsServers.orEmpty()
        }, Os::rename)

    internal fun writeResolvConfFromNetwork(
        rootfs: File,
        readNetwork: () -> List<InetAddress>,
        replace: (String, String) -> Unit,
    ): DnsConfigReport {
        var networkRead = DnsNetworkRead.READ
        val addresses = try {
            readNetwork().also { if (it.isEmpty()) networkRead = DnsNetworkRead.EMPTY }
        } catch (_: Exception) {
            networkRead = DnsNetworkRead.FAILED
            emptyList()
        }
        return writeResolvConf(rootfs, pickDns(addresses), replace).copy(networkRead = networkRead)
    }

    /** Up to two of the network's servers, IPv4 first, then the public fallbacks: three in all. */
    fun pickDns(addrs: List<InetAddress>): List<String> {
        val network = addrs.filterNot { it.isLinkLocalAddress }
            .sortedBy { if (it is Inet4Address) 0 else 1 }
            .mapNotNull { it.hostAddress?.substringBefore('%') }.distinct().take(2)
        return (network + FALLBACK_DNS).distinct().take(3)
    }

    fun writeResolvConf(rootfs: File, servers: List<String>): DnsConfigReport =
        writeResolvConf(rootfs, servers, Os::rename)

    internal fun writeResolvConf(
        rootfs: File,
        servers: List<String>,
        replace: (String, String) -> Unit,
    ): DnsConfigReport {
        val requested = servers.take(3).toList()
        val text = buildString {
            appendLine("# written by dsh-app from the device's active network")
            servers.forEach { appendLine("nameserver $it") }
            appendLine("options ${DnsConfigReport.OPTIONS}")
        }
        var stage = DnsConfigStage.PREPARE
        try {
            val etc = File(rootfs, "etc")
            if (!etc.isDirectory && !etc.mkdirs() && !etc.isDirectory) throw IOException("Cannot prepare resolver directory")
            val target = File(etc, "resolv.conf")
            stage = DnsConfigStage.READ
            if (target.isFile && target.readText() == text) return DnsConfigReport(DnsConfigOutcome.UNCHANGED, requested)
            // Swapped in whole while DSH runs; also replaces a symlink (e.g. to systemd-resolved) with a plain file.
            val temp = File(etc, ".resolv.conf.dsh-tmp")
            stage = DnsConfigStage.WRITE
            temp.writeText(text)
            stage = DnsConfigStage.REPLACE
            replace(temp.path, target.path)
            return DnsConfigReport(DnsConfigOutcome.WRITTEN, requested)
        } catch (e: Exception) {
            val error = when (e) {
                is ErrnoException -> DnsConfigError.NATIVE
                is SecurityException -> DnsConfigError.SECURITY
                is IOException -> DnsConfigError.IO
                else -> DnsConfigError.OTHER
            }
            return DnsConfigReport(DnsConfigOutcome.FAILED, requested, stage, error, (e as? ErrnoException)?.errno)
        }
    }
}
