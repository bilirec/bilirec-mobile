package org.bilirec.bilirec

import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import com.antonkarpenko.ffmpegkit.FFmpegKitConfig
import com.antonkarpenko.ffmpegkit.Level
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FFmpegKitConfig.enableLogCallback { log ->
            if (log.level < Level.AV_LOG_INFO) return@enableLogCallback
            LogBridge.enqueueLog(log.sessionId, log.level.value, log.message ?: "")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APK_SIGNATURE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "matchesInstalledSigningCertificates" -> {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath.isNullOrEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(matchesInstalledSigningCertificates(apkPath))
                    } catch (e: Exception) {
                        result.error("APK_SIGNATURE_CHECK_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun matchesInstalledSigningCertificates(apkPath: String): Boolean {
        val apkFile = File(apkPath)
        if (!apkFile.isFile || !apkFile.exists()) {
            return false
        }

        val flags = signingInfoFlags()
        val installed = packageInfoForInstalledApp(flags) ?: return false
        val archive = packageInfoForArchive(apkPath, flags) ?: return false
        if (archive.packageName != packageName) {
            return false
        }

        val installedCerts = signingCertificateBytes(installed)
        val archiveCerts = signingCertificateBytes(archive)
        return installedCerts.isNotEmpty() && installedCerts == archiveCerts
    }

    private fun signingInfoFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
    }

    private fun packageInfoForInstalledApp(flags: Int): PackageInfo? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(flags.toLong()),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, flags)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun packageInfoForArchive(apkPath: String, flags: Int): PackageInfo? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageArchiveInfo(
                apkPath,
                PackageManager.PackageInfoFlags.of(flags.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageArchiveInfo(apkPath, flags)
        }
    }

    private fun signingCertificateBytes(info: PackageInfo): Set<List<Byte>> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo ?: return emptySet()
            val signers = if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
            return certSet(signers)
        }

        @Suppress("DEPRECATION")
        return certSet(info.signatures)
    }

    private fun certSet(signatures: Array<android.content.pm.Signature>?): Set<List<Byte>> {
        if (signatures.isNullOrEmpty()) {
            return emptySet()
        }
        return signatures.map { it.toByteArray().toList() }.toSet()
    }

    companion object {
        private const val APK_SIGNATURE_CHANNEL = "org.bilirec.bilirec/apk_signature"
    }
}
