package dev.nolyf.dsh_red.runtime

import java.io.File
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

/**
 * The engine's endpoint: which port it serves on and which token it answers to.
 *
 * The app reads both from the engine's own log. After a restart the log used
 * to hold the earlier run's token line as well, and the app then talked to
 * the new engine with a token the new engine refused: every request failed
 * with "can't reach the engine" while the engine was running perfectly well.
 */
class EngineEndpointTest {
    private fun log(lines: List<String>): File {
        val file = Files.createTempDirectory("engine-log").toFile().resolve("dsh-web.log")
        file.writeText(lines.joinToString("\n"))
        return file
    }

    private val tokenLine = "dsh web: http://127.0.0.1:3080/?token=first-token"

    @Test fun aTokenLineNamesItsPortAndItsToken() {
        val (port, token) = DshProcess.tokenLine(tokenLine)!!
        assertEquals(3080, port)
        assertEquals("first-token", token)
    }

    @Test fun aLineWithoutATokenIsNoTokenLine() {
        assertNull(DshProcess.tokenLine("dsh web: listening on http://127.0.0.1:3080/"))
        assertNull(DshProcess.tokenLine(""))
    }

    @Test fun theEndpointIsTheLastTokenLineOfTheLog() {
        val file = log(
            listOf(
                "dsh web: http://127.0.0.1:3080/?token=old-token",
                "some other output",
                "dsh web: http://127.0.0.1:3090/?token=new-token",
            ),
        )
        try {
            val (base, token) = DshProcess.endpointFromLog(file)!!
            assertEquals("http://127.0.0.1:3090", base)
            assertEquals("new-token", token)
        } finally {
            file.delete()
        }
    }

    @Test fun aLogWithoutATokenLineHasNoEndpoint() {
        val file = log(listOf("dsh web: starting", "nothing to see"))
        try {
            assertNull(DshProcess.endpointFromLog(file))
        } finally {
            file.delete()
        }
    }

    @Test fun aMissingLogHasNoEndpoint() {
        val missing = File(System.getProperty("java.io.tmpdir"), "no-such-engine-log-${System.nanoTime()}.log")
        assertNull(DshProcess.endpointFromLog(missing))
    }

    /** The launch script starts the engine with its log truncated. */
    @Test fun theEngineLogHoldsThisRunOnly() {
        val script = ChrootRuntime.launchScript(
            listOf("/bin/sh", "-c", "exec /usr/local/bin/dsh web --port 3080"),
            emptyMap(),
            3080,
        )
        assertTrue(script, script.contains("> /root/.dsh/dsh-app/dsh-web.log 2>&1"))
        assertFalse(script, script.contains(">> /root/.dsh/dsh-app/dsh-web.log"))
    }
}
