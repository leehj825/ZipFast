package com.zipfast.zipfast

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Reports and requests Android "All files access" so extraction/creation can target any folder. */
class StoragePlugin(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.zipfast.zipfast/storage")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAllFilesAccess" -> result.success(hasAccess())
                "openAllFilesAccessSettings" -> {
                    openSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAccess(): Boolean =
        // Below Android 11 the legacy storage permissions apply instead.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) Environment.isExternalStorageManager() else true

    private fun openSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val intent = Intent(
            Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
            Uri.parse("package:${context.packageName}")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }
}
