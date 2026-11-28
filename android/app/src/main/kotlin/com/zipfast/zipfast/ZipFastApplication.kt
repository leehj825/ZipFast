package com.zipfast.zipfast

import android.app.Application
import android.content.Context

/**
 * Installs the crash reporter as early as possible. `attachBaseContext` runs before content
 * providers (androidx.startup, ads, WorkManager) are created, which is where start-up crashes
 * tend to happen.
 */
class ZipFastApplication : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        CrashReporter.install(this)
    }
}
