package com.zipfast.zipfast

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.concurrent.thread

/**
 * Hands archives opened via "Open with ZipFast" to Dart.
 *
 * A `content://` stream cannot be read with dart:io, so it is copied into the
 * app cache first (on a worker thread, large archives take a while) and Dart
 * receives the resulting local path.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var enginePlugin: EnginePlugin? = null
    private var storagePlugin: StoragePlugin? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Result of the launch intent, or a Dart request waiting for it.
    private var initialPath: String? = null
    private var initialResolved = false
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        enginePlugin = EnginePlugin(flutterEngine.dartExecutor.binaryMessenger)
        storagePlugin = StoragePlugin(this, flutterEngine.dartExecutor.binaryMessenger)
        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.zipfast.zipfast/incoming"
        )
        channel = ch
        ch.setMethodCallHandler { call, result ->
            if (call.method == "getInitialFile") {
                if (initialResolved) {
                    result.success(initialPath)
                    initialPath = null
                } else {
                    pendingResult = result
                }
            } else {
                result.notImplemented()
            }
        }
        resolveIntent(intent) { path ->
            initialResolved = true
            initialPath = path
            pendingResult?.let {
                it.success(path)
                initialPath = null
                pendingResult = null
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        resolveIntent(intent) { path ->
            if (path != null) channel?.invokeMethod("onNewFile", path)
        }
    }

    /** Resolves [intent] to a local file path and calls [done] on the main thread. */
    private fun resolveIntent(intent: Intent?, done: (String?) -> Unit) {
        val uri: Uri? = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
        if (uri == null) {
            done(null)
            return
        }
        thread {
            val path = try {
                copyToCache(uri)
            } catch (e: Exception) {
                null
            }
            mainHandler.post { done(path) }
        }
    }

    private fun copyToCache(uri: Uri): String? {
        if (uri.scheme == "file") {
            val file = File(uri.path ?: return null)
            return if (file.canRead()) file.absolutePath else null
        }
        val dir = File(cacheDir, "incoming").apply { mkdirs() }
        // One incoming archive at a time keeps the cache from growing.
        dir.listFiles()?.forEach { it.delete() }

        var name = "archive"
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c ->
                if (c.moveToFirst()) {
                    val i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (i >= 0) c.getString(i)?.let { name = it }
                }
            }
        // Never let a hostile display name escape the cache directory.
        name = File(name).name.replace(Regex("[\\\\/:*?\"<>|]"), "_").ifEmpty { "archive" }

        val out = File(dir, name)
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(out).use { output -> input.copyTo(output, 256 * 1024) }
        } ?: return null
        return out.absolutePath
    }
}
