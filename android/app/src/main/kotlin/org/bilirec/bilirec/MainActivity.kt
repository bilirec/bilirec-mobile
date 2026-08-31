package org.bilirec.bilirec

import android.os.Bundle
import com.antonkarpenko.ffmpegkit.FFmpegKitConfig
import com.antonkarpenko.ffmpegkit.Level
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        StorageBridge.install(applicationContext)
        FFmpegKitConfig.enableLogCallback { log ->
            if (log.level < Level.AV_LOG_INFO) return@enableLogCallback
            LogBridge.enqueueLog(log.sessionId, log.level.value, log.message ?: "")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(ApkSignaturePlugin())
    }
}
