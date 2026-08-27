package org.bilirec.bilirec

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class ApkSignaturePlugin : FlutterPlugin {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val verifier = ApkSignatureVerifier(binding.applicationContext)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "matchesInstalledSigningCertificates" -> {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath.isNullOrEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(verifier.matchesInstalledSigningCertificates(apkPath))
                    } catch (e: Exception) {
                        result.error("APK_SIGNATURE_CHECK_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val CHANNEL = "org.bilirec.bilirec/apk_signature"
    }
}
