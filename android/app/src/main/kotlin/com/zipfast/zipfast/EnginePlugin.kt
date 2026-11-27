package com.zipfast.zipfast

import android.os.Handler
import android.os.Looper
import com.zipfast.zipfast.engine.ArchiveBridge
import com.zipfast.zipfast.engine.BridgeException
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Exposes the 7-Zip based [ArchiveBridge] to Dart (RAR/RAR5, 7Z, ISO, CAB,
 * split volumes, encryption). Work runs on worker threads; progress is pushed
 * back as `progress` calls and jobs can be cancelled by id.
 */
class EnginePlugin(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.zipfast.zipfast/engine")
    private val executor = Executors.newCachedThreadPool()
    private val main = Handler(Looper.getMainLooper())
    private val cancels = ConcurrentHashMap<Int, AtomicBoolean>()

    init {
        channel.setMethodCallHandler { call, result -> onCall(call, result) }
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "list" -> {
                val path = call.argument<String>("path")!!
                val password = call.argument<String>("password")
                run(result) { ArchiveBridge.list(path, password) }
            }

            "readEntry" -> {
                val path = call.argument<String>("path")!!
                val entry = call.argument<String>("entry")!!
                val password = call.argument<String>("password")
                val max = call.argument<Number>("maxBytes")!!.toLong()
                run(result) { ArchiveBridge.readEntry(path, entry, password, max) }
            }

            "extract" -> {
                val id = call.argument<Int>("id")!!
                val path = call.argument<String>("path")!!
                val password = call.argument<String>("password")
                val dest = call.argument<String>("destination")!!
                val selected = call.argument<List<String>>("selected")
                val conflict = call.argument<String>("conflict") ?: "rename"
                val cancel = AtomicBoolean(false)
                cancels[id] = cancel
                run(result, onFinish = { cancels.remove(id) }) {
                    ArchiveBridge.extract(path, password, dest, selected, conflict, progress(id), cancel)
                }
            }

            "create7z" -> {
                val id = call.argument<Int>("id")!!
                val sources = call.argument<List<String>>("sources")!!
                val output = call.argument<String>("output")!!
                val level = call.argument<Int>("level") ?: 5
                val password = call.argument<String>("password")
                val cancel = AtomicBoolean(false)
                cancels[id] = cancel
                run(result, onFinish = { cancels.remove(id) }) {
                    ArchiveBridge.create7z(sources, output, level, password, progress(id), cancel)
                }
            }

            "cancel" -> {
                cancels[call.argument<Int>("id")]?.set(true)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun progress(id: Int) = ArchiveBridge.Progress { done, total, current ->
        main.post {
            channel.invokeMethod(
                "progress",
                mapOf("id" to id, "done" to done, "total" to total, "current" to current)
            )
        }
    }

    private fun <T> run(
        result: MethodChannel.Result,
        onFinish: () -> Unit = {},
        block: () -> T
    ) {
        executor.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: BridgeException) {
                main.post { result.error(e.code, e.message, null) }
            } catch (e: Throwable) {
                main.post { result.error(BridgeException.CORRUPT, e.toString(), null) }
            } finally {
                onFinish()
            }
        }
    }
}
