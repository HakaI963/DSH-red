package io.github.ccch1mneyyy.dsh_app.runtime

/**
 * Where each phone maker keeps the switches stock Android doesn't have and no API reports:
 * "let this app keep running (and online) in the background", "start by itself", and "open
 * screens from the background".
 *
 * On these ROMs a foreground service is not enough: vivo, for one, cuts the app's network as
 * soon as it leaves the screen unless "Allow high background power usage" is on (confirmed on OriginOS 16). The
 * pages below are the vendors' own activities, reverse-engineered and liable to move between ROM
 * versions, so each is tried only if it resolves and is exported, and the app's system details
 * page (which links to the same switches on all of them) is the fallback.
 *
 * Which switches a maker has is the Dart side's table too (`lib/state/access_state.dart`,
 * `vendorSwitches`): a switch with no page here still opens the details page.
 */
object VendorSettings {
    /**
     * One vendor activity, by component ([cls]) or by [action] inside [pkg]. [packageExtra] /
     * [labelExtra] name the extras that carry this app's package and label, when the page wants them.
     */
    data class Page(
        val pkg: String,
        val cls: String? = null,
        val action: String? = null,
        val packageExtra: String? = null,
        val labelExtra: String? = null,
    )

    /** A maker's switch, as the Dart side names it on the wire. */
    enum class Switch(val wire: String) {
        /** Allow high background power usage (vivo), Battery saver (Xiaomi), App launch (Huawei, Honor), Background activity (OPPO). */
        BACKGROUND("background"),

        /** Auto-start. */
        AUTOSTART("autostart"),

        /** Display pop-up windows in background: phone control brings the app back after a task. */
        POPUP("popup");

        companion object {
            fun parse(wire: String?): Switch? = values().firstOrNull { it.wire == wire }
        }
    }

    const val VIVO = "vivo"
    const val XIAOMI = "xiaomi"
    const val HUAWEI = "huawei"
    const val HONOR = "honor"
    const val OPPO = "oppo"
    const val SAMSUNG = "samsung"

    /** The vendor key for `Build.MANUFACTURER` / `Build.BRAND`; null for stock Android and the rest. */
    fun vendorOf(manufacturer: String?, brand: String?): String? = match(manufacturer) ?: match(brand)

    private fun match(name: String?): String? {
        val n = name?.trim()?.lowercase() ?: return null
        fun any(vararg keys: String) = keys.any { n.startsWith(it) }
        return when {
            any("vivo", "iqoo") -> VIVO
            any("xiaomi", "redmi", "poco") -> XIAOMI
            // Older Honor phones say HUAWEI here and run Huawei's manager; checked first.
            any("huawei") -> HUAWEI
            any("honor", "hihonor") -> HONOR
            any("oppo", "oneplus", "realme") -> OPPO
            any("samsung") -> SAMSUNG
            else -> null
        }
    }

    private const val VIVO_PERMISSIONS = "com.vivo.permissionmanager"
    private const val IQOO_SECURE = "com.iqoo.secure"
    private const val MIUI_SECURITY = "com.miui.securitycenter"
    private const val HUAWEI_MANAGER = "com.huawei.systemmanager"
    private const val HONOR_MANAGER = "com.hihonor.systemmanager"

    /**
     * Vendor pages to try for [switch], best first; empty: the app's details page. OPPO and
     * Samsung keep their switches there; Huawei's and Honor's App launch holds start-up and
     * background running in one place, so they have no separate auto-start page.
     */
    fun pages(vendor: String?, switch: Switch = Switch.BACKGROUND): List<Page> = when (vendor) {
        VIVO -> when (switch) {
            Switch.BACKGROUND -> listOf(
                // Battery › Background power consumption management (the "Allow high background power usage" list).
                Page("com.vivo.abe", "com.vivo.applicationbehaviorengine.ui.ExcessivePowerManagerActivity"),
                Page("com.iqoo.powersaving", "com.iqoo.powersaving.PowerSavingManagerActivity"),
            )
            Switch.AUTOSTART -> listOf(
                // Permission manager › Auto-start (OriginOS, FuntouchOS 3+), then i Manager's older list.
                Page(VIVO_PERMISSIONS, "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
                Page(IQOO_SECURE, "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"),
                Page(IQOO_SECURE, "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            )
            Switch.POPUP -> listOf(
                // This app's own permission page in Permission manager (background pop-ups, show on lock screen, display over other apps).
                Page(VIVO_PERMISSIONS, "com.vivo.permissionmanager.activity.SoftPermissionDetailActivity", packageExtra = "packagename"),
                Page(VIVO_PERMISSIONS, action = "permission.intent.action.softPermissionDetail", packageExtra = "packagename"),
                Page(VIVO_PERMISSIONS, "com.vivo.permissionmanager.activity.PurviewTabActivity"),
            )
        }
        XIAOMI -> when (switch) {
            // This app's own Battery saver page.
            Switch.BACKGROUND -> listOf(
                Page("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity", packageExtra = "package_name", labelExtra = "package_label"),
            )
            Switch.AUTOSTART -> listOf(Page(MIUI_SECURITY, "com.miui.permcenter.autostart.AutoStartManagementActivity"))
            // Other permissions for this app: background pop-ups sit there (MIUI 8+, HyperOS), then the MIUI 6/7 page.
            Switch.POPUP -> listOf(
                Page(MIUI_SECURITY, "com.miui.permcenter.permissions.PermissionsEditorActivity", packageExtra = "extra_pkgname"),
                Page(MIUI_SECURITY, "com.miui.permcenter.permissions.AppPermissionsEditorActivity", packageExtra = "extra_pkgname"),
            )
        }
        HUAWEI -> if (switch == Switch.BACKGROUND) {
            listOf(
                Page(HUAWEI_MANAGER, "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                Page(HUAWEI_MANAGER, "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity"),
                Page(HUAWEI_MANAGER, "com.huawei.systemmanager.optimize.process.ProtectActivity"),
            )
        } else {
            emptyList()
        }
        HONOR -> if (switch == Switch.BACKGROUND) {
            listOf(
                Page(HONOR_MANAGER, "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                Page(HUAWEI_MANAGER, "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            )
        } else {
            emptyList()
        }
        else -> emptyList()
    }
}
