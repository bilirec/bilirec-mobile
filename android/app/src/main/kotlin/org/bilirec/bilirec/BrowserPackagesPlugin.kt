package org.bilirec.bilirec

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class BrowserPackagesPlugin : FlutterPlugin {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "listHttpsBrowsers" -> {
                    try {
                        result.success(listHttpsBrowsers())
                    } catch (e: Exception) {
                        result.error("LIST_HTTPS_BROWSERS_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun listHttpsBrowsers(): List<Map<String, String>> {
        val pm = context.packageManager
        val selfPackage = context.packageName
        val byPackage = linkedMapOf<String, String>()

        for (scheme in listOf("http", "https")) {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("$scheme://"))
            intent.addCategory(Intent.CATEGORY_BROWSABLE)
            val resolved = queryActivities(pm, intent)
            for (info in resolved) {
                val pkg = info.activityInfo?.packageName ?: continue
                if (pkg == selfPackage) continue
                if (byPackage.containsKey(pkg)) continue
                val label = info.loadLabel(pm)?.toString()?.trim()
                byPackage[pkg] = if (label.isNullOrEmpty()) pkg else label
            }
        }

        return byPackage.entries
            .map { (packageName, label) ->
                mapOf("packageName" to packageName, "label" to label)
            }
            .sortedBy { it["label"]?.lowercase() ?: "" }
    }

    private fun queryActivities(
        pm: PackageManager,
        intent: Intent,
    ): List<ResolveInfo> {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PackageManager.MATCH_ALL
        } else {
            @Suppress("DEPRECATION")
            PackageManager.MATCH_DEFAULT_ONLY
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(flags.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, flags)
        }
    }

    companion object {
        private const val CHANNEL = "org.bilirec.bilirec/browser_packages"
    }
}
