package dev.nolyf.dsh_red.phone

import android.app.AppOpsManager
import dev.nolyf.dsh_red.phone.RestrictedSettings.ACKNOWLEDGED
import dev.nolyf.dsh_red.phone.RestrictedSettings.CLEAR
import dev.nolyf.dsh_red.phone.RestrictedSettings.GUARDED
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RestrictedSettingsTest {
    @Test fun beforeAndroid13NothingIsRestricted() {
        assertEquals(CLEAR, RestrictedSettings.state(32, AppOpsManager.MODE_ERRORED, 3))
        assertEquals(CLEAR, RestrictedSettings.state(26, null, null))
    }

    @Test fun theOpModeSaysWhereThePersonIs() {
        // A store install, or allowed on App info.
        assertEquals(CLEAR, RestrictedSettings.state(33, AppOpsManager.MODE_ALLOWED, 3))
        // Sideloaded: the switch is greyed out and App info's ⋮ has nothing yet.
        assertEquals(GUARDED, RestrictedSettings.state(34, AppOpsManager.MODE_ERRORED, 4))
        // The "Restricted setting" dialog was seen: ⋮ offers "Allow restricted settings" now.
        assertEquals(ACKNOWLEDGED, RestrictedSettings.state(34, AppOpsManager.MODE_IGNORED, 4))
    }

    @Test fun android15DefaultsByWhereTheAppCameFrom() {
        assertEquals(GUARDED, RestrictedSettings.state(35, AppOpsManager.MODE_DEFAULT, 3))
        assertEquals(GUARDED, RestrictedSettings.state(35, AppOpsManager.MODE_DEFAULT, 4))
        assertEquals(CLEAR, RestrictedSettings.state(35, AppOpsManager.MODE_DEFAULT, 2))
        assertEquals(CLEAR, RestrictedSettings.state(35, AppOpsManager.MODE_DEFAULT, 1))
        // Unspecified source: can't be told.
        assertNull(RestrictedSettings.state(35, AppOpsManager.MODE_DEFAULT, 0))
        assertNull(RestrictedSettings.state(35, AppOpsManager.MODE_DEFAULT, null))
    }

    @Test fun anAnswerTheRomShouldNotGiveIsUnknown() {
        assertNull(RestrictedSettings.state(34, null, 4))
        assertNull(RestrictedSettings.state(34, AppOpsManager.MODE_FOREGROUND, 4))
    }
}
