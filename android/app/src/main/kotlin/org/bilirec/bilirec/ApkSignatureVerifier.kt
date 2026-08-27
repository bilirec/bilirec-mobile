package org.bilirec.bilirec

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import java.io.File

class ApkSignatureVerifier(private val context: Context) {
    fun matchesInstalledSigningCertificates(apkPath: String): Boolean {
        val apkFile = File(apkPath)
        if (!apkFile.isFile || !apkFile.exists()) {
            return false
        }

        val flags = signingInfoFlags()
        val installed = packageInfoForInstalledApp(flags) ?: return false
        val archive = packageInfoForArchive(apkPath, flags) ?: return false
        if (archive.packageName != context.packageName) {
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
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.PackageInfoFlags.of(flags.toLong()),
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(context.packageName, flags)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun packageInfoForArchive(apkPath: String, flags: Int): PackageInfo? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getPackageArchiveInfo(
                apkPath,
                PackageManager.PackageInfoFlags.of(flags.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageArchiveInfo(apkPath, flags)
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

    private fun certSet(signatures: Array<Signature>?): Set<List<Byte>> {
        if (signatures.isNullOrEmpty()) {
            return emptySet()
        }
        return signatures.map { it.toByteArray().toList() }.toSet()
    }
}
