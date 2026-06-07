package org.bilirec.bilirec

import android.os.Bundle
import com.antonkarpenko.ffmpegkit.FFmpegKitConfig
import com.antonkarpenko.ffmpegkit.Level
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FFmpegKitConfig.enableLogCallback { log ->
            if (log.level < Level.AV_LOG_INFO) return@enableLogCallback
            LogBridge.enqueueLog(log.sessionId, log.level.value, log.message ?: "")
        }
    }
}
