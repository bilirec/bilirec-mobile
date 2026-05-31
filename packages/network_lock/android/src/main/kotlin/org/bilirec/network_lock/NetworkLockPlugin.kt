package org.bilirec.network_lock

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class NetworkLockPlugin: FlutterPlugin {
    private lateinit var channel: MethodChannel
    private lateinit var wifiLockManager: WifiLockManager
    private lateinit var cellularLockManager: CellularLockManager

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        wifiLockManager = WifiLockManager(context)
        cellularLockManager = CellularLockManager(context)

        channel = MethodChannel(binding.binaryMessenger, "org.bilirec.bilirec/network_lock")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> run(result) {
                    val networkType = call.argument<String>("type")
                    if (networkType == "cellular") {
                        wifiLockManager.releaseHighPerfLock()
                        cellularLockManager.acquireCellularLock()
                    } else {
                        cellularLockManager.releaseCellularLock()
                        wifiLockManager.acquireHighPerfLock()
                    }
                }
                "disable" -> run(result) {
                    wifiLockManager.releaseHighPerfLock()
                    cellularLockManager.releaseCellularLock()
                }
                "status" -> send(result) {
                    mapOf(
                        "wifiLocked" to wifiLockManager.isLocked,
                        "cellularLocked" to cellularLockManager.isLocked
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun run(result: MethodChannel.Result, block: () -> Unit) {
        try {
            block()
            result.success(true)
        } catch (e: Exception) {
            Log.e("BiliRec", "Fatal error in enable", e)
            result.error("INTERNAL_ERROR", e.message, null)
        }
    }

    private fun send(result: MethodChannel.Result, block: () -> Any) {
        try {
            result.success(block())
        } catch (e: Exception) {
            Log.e("BiliRec", "Fatal error in send", e)
            result.error("INTERNAL_ERROR", e.message, null)
        }
    }
}