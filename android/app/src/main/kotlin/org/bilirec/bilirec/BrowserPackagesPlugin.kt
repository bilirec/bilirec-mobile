package org.bilirec.bilirec

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class BrowserPackagesPlugin : FlutterPlugin {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val mainHandler = Handler(Looper.getMainLooper())
    private var worker: ExecutorService? = null
    private val resolveInfoByPackage = linkedMapOf<String, ResolveInfo>()
    private val iconPngCache = linkedMapOf<String, ByteArray>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        worker = Executors.newSingleThreadExecutor()
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "listHttpsBrowsers" -> {
                    runOnWorker(result) {
                        listHttpsBrowsers()
                    }
                }
                "loadHttpsBrowserIcons" -> {
                    val packageNames = call.argument<List<String>>("packageNames")
                    if (packageNames == null) {
                        mainHandler.post { result.success(mapOf<String, ByteArray>()) }
                        return@setMethodCallHandler
                    }
                    runOnWorker(result) {
                        loadHttpsBrowserIcons(packageNames)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        worker?.shutdownNow()
        worker = null
        resolveInfoByPackage.clear()
        iconPngCache.clear()
    }

    private fun runOnWorker(
        result: MethodChannel.Result,
        block: () -> Any?,
    ) {
        val executor = worker
        if (executor == null) {
            result.error("PLUGIN_DETACHED", "BrowserPackagesPlugin is not attached", null)
            return
        }
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("BROWSER_PACKAGES_FAILED", e.message, null)
                }
            }
        }
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
                resolveInfoByPackage[pkg] = info
            }
        }

        return byPackage.entries
            .map { (packageName, label) ->
                mapOf("packageName" to packageName, "label" to label)
            }
            .sortedBy { it["label"]?.lowercase() ?: "" }
    }

    private fun loadHttpsBrowserIcons(packageNames: List<String>): Map<String, ByteArray> {
        val pm = context.packageManager
        val out = linkedMapOf<String, ByteArray>()
        val iconSizePx = iconSizePx()

        for (packageName in packageNames) {
            if (packageName.isBlank()) continue
            val cacheKey = iconCacheKey(pm, packageName)
            val cached = iconPngCache[cacheKey]
            if (cached != null) {
                out[packageName] = cached
                continue
            }

            val info = resolveInfoByPackage[packageName]
                ?: resolveInfoForPackage(pm, packageName)
            if (info == null) continue

            val png = encodeIconPng(pm, info, iconSizePx) ?: continue
            iconPngCache[cacheKey] = png
            out[packageName] = png
        }

        return out
    }

    private fun iconCacheKey(pm: PackageManager, packageName: String): String {
        val lastUpdate = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0),
                ).lastUpdateTime
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(packageName, 0).lastUpdateTime
            }
        } catch (_: Exception) {
            0L
        }
        return "$packageName:$lastUpdate"
    }

    private fun resolveInfoForPackage(
        pm: PackageManager,
        packageName: String,
    ): ResolveInfo? {
        for (scheme in listOf("https", "http")) {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("$scheme://"))
            intent.addCategory(Intent.CATEGORY_BROWSABLE)
            intent.setPackage(packageName)
            val resolved = queryActivities(pm, intent)
            val match = resolved.firstOrNull { info ->
                info.activityInfo?.packageName == packageName
            }
            if (match != null) {
                resolveInfoByPackage[packageName] = match
                return match
            }
        }
        return null
    }

    private fun encodeIconPng(
        pm: PackageManager,
        info: ResolveInfo,
        iconSizePx: Int,
    ): ByteArray? {
        val drawable = info.loadIcon(pm) ?: return null
        val bitmap = drawableToBitmap(drawable, iconSizePx) ?: return null
        val stream = ByteArrayOutputStream()
        if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
            bitmap.recycle()
            return null
        }
        bitmap.recycle()
        return stream.toByteArray()
    }

    private fun iconSizePx(): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            ICON_SIZE_DP.toFloat(),
            context.resources.displayMetrics,
        ).toInt().coerceAtLeast(1)
    }

    private fun drawableToBitmap(drawable: Drawable, sizePx: Int): Bitmap? {
        if (sizePx <= 0) return null
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            Bitmap.createScaledBitmap(drawable.bitmap, sizePx, sizePx, true)
        } else {
            val bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, sizePx, sizePx)
            drawable.draw(canvas)
            bmp
        }
        return bitmap
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
        private const val ICON_SIZE_DP = 48
    }
}
