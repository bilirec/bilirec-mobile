package org.bilirec.bilirec

import android.os.Bundle
import com.antonkarpenko.ffmpegkit.FFmpegKitConfig
import com.antonkarpenko.ffmpegkit.Level
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Permission changes may recreate this Activity after the IDE debugger
        // has detached; replaying this one-shot flag would freeze the new VM.
        if (BuildConfig.DEBUG && savedInstanceState != null) {
            intent.removeExtra("start-paused")
        }
        super.onCreate(savedInstanceState)
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
