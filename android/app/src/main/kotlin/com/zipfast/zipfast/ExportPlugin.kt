package com.zipfast.zipfast

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import com.zipfast.zipfast.engine.BridgeException
import com.zipfast.zipfast.engine.TreeExporter
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.OutputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * "Save a copy to…": copies files out of ZipFast's storage into a folder the user
 * picks with the system folder picker (Storage Access Framework).
 *
 * No storage permission is involved: choosing the folder is the grant, and it
 * is kept (persistable) so the folder can be reused. The copy itself is
 * [TreeExporter], which is unit-tested on the JVM; this class only adapts it to
 * `DocumentsContract`.
 */
class ExportPlugin(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.zipfast.zipfast/export")
    private val executor = Executors.newCachedThreadPool()
    private val main = Handler(Looper.getMainLooper())
    private val cancels = ConcurrentHashMap<Int, AtomicBoolean>()
    private var pendingPick: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result -> onCall(call, result) }
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFolder" -> pickFolder(result)
            "hasAccess" -> result.success(hasAccess(call.argument<String>("uri")!!))
            "copy" -> copy(call, result)
            "cancel" -> {
                cancels[call.argument<Int>("id")]?.set(true)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // --- picking -----------------------------------------------------------

    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("BUSY", "A folder picker is already open", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
        )
        try {
            activity.startActivityForResult(intent, REQUEST_PICK)
        } catch (e: Exception) {
            pendingPick = null
            result.error("NO_PICKER", e.toString(), null)
        }
    }

    /** Forward from `Activity.onActivityResult`. Returns true if it was ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode == Activity.RESULT_OK && uri != null) {
            try {
                activity.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            } catch (e: SecurityException) {
                // Not persistable: still usable for this session.
            }
            result.success(uri.toString())
        } else {
            result.success(null)
        }
        return true
    }

    /** Whether a previously picked folder is still writable (the user can revoke it). */
    private fun hasAccess(uri: String): Boolean =
        activity.contentResolver.persistedUriPermissions.any {
            it.uri.toString() == uri && it.isWritePermission
        }

    // --- copying -----------------------------------------------------------

    private fun copy(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Int>("id")!!
        val tree = Uri.parse(call.argument<String>("uri")!!)
        val paths = call.argument<List<String>>("paths")!!
        val cancel = AtomicBoolean(false)
        cancels[id] = cancel
        val resolver = activity.contentResolver

        executor.execute {
            try {
                val copied = TreeExporter.copy(paths, SafTarget(resolver, tree), { done, total, current ->
                    main.post {
                        channel.invokeMethod(
                            "progress",
                            mapOf("id" to id, "done" to done, "total" to total, "current" to current)
                        )
                    }
                }, cancel)
                main.post { result.success(copied) }
            } catch (e: BridgeException) {
                main.post { result.error(e.code, e.message, null) }
            } catch (e: SecurityException) {
                main.post { result.error("PERMISSION", e.message, null) }
            } catch (e: Throwable) {
                main.post { result.error(BridgeException.CORRUPT, e.toString(), null) }
            } finally {
                cancels.remove(id)
            }
        }
    }

    /** A SAF folder as a [TreeExporter.Target]. */
    private class SafTarget(private val resolver: ContentResolver, private val tree: Uri) :
        TreeExporter.Target {
        override fun root(): Any =
            DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

        override fun createFolder(parent: Any, name: String): Any =
            DocumentsContract.createDocument(
                resolver, parent as Uri, DocumentsContract.Document.MIME_TYPE_DIR, name
            ) ?: throw IOException("Could not create folder $name")

        override fun createFile(parent: Any, name: String, mimeType: String): OutputStream {
            val doc = DocumentsContract.createDocument(resolver, parent as Uri, mimeType, name)
                ?: throw IOException("Could not create $name")
            return resolver.openOutputStream(doc) ?: throw IOException("Could not open $name")
        }
    }

    companion object {
        const val REQUEST_PICK = 4711
    }
}
