package com.zipfast.zipfast

import android.app.Application
import android.content.Intent
import android.os.Build
import java.io.PrintWriter
import java.io.StringWriter

/**
 * Shows a plain Android screen with the stack trace when the app dies from an uncaught
 * Java/Kotlin exception, so a crash during start-up (before any Flutter code runs) can be
 * read and reported without adb.
 *
 * The screen lives in its own process (":crash"), so it survives the dying app process.
 * It cannot catch native (SIGSEGV) crashes.
 */
object CrashReporter {
    const val EXTRA_REPORT = "zipfast.crash_report"

    fun install(app: Application) {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                // Never report a crash of the report screen itself (would loop).
                if (!error.stackTraceToString().contains("CrashActivity")) {
                    val intent = Intent(app, CrashActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                        .putExtra(EXTRA_REPORT, buildReport(app, thread, error))
                    app.startActivity(intent)
                }
            } catch (_: Throwable) {
                // Reporting must never make things worse.
            }
            // Let the system finish the job (logs it and ends the process).
            previous?.uncaughtException(thread, error)
        }
    }

    private fun buildReport(app: Application, thread: Thread, error: Throwable): String {
        val version = try {
            val info = app.packageManager.getPackageInfo(app.packageName, 0)
            "${info.versionName} (${info.longVersionCode})"
        } catch (_: Throwable) {
            "?"
        }
        val trace = StringWriter().also { error.printStackTrace(PrintWriter(it)) }.toString()
        return buildString {
            appendLine("ZipFast $version")
            appendLine("Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
            appendLine("${Build.MANUFACTURER} ${Build.MODEL}, ABIs ${Build.SUPPORTED_ABIS.joinToString()}")
            appendLine("Thread: ${thread.name}")
            appendLine()
            append(trace.take(12000))
        }
    }
}
