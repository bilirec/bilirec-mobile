package org.bilirec.bilirec

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.time.Duration.Companion.seconds

object LogBridge {
    external fun sendFFmpegLog(sessionId: Long, level: Int, message: String)

    private data class LogKey(val sessionId: Long, val level: Int)
    private class LogBuffer {
        val sb = StringBuilder()
        var lineCount = 0
    }

    private sealed interface LogEvent {
        data class Allocate(val sessionId: Long, val level: Int, val text: String) : LogEvent
        object DebounceSweep : LogEvent
    }

    private val eventChannel = Channel<LogEvent>(Channel.UNLIMITED)
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    init {
        System.loadLibrary("bilirec")

        scope.launch {
            while (isActive) {
                delay(3.seconds)
                eventChannel.trySend(LogEvent.DebounceSweep)
            }
        }

        scope.launch {
            val buffers = HashMap<LogKey, LogBuffer>()
            val lastActiveTimes = HashMap<Long, Long>() // 記錄每個 sessionId 的最後活躍時間戳

            for (event in eventChannel) {
                when (event) {
                    is LogEvent.Allocate -> {
                        val now = System.currentTimeMillis()
                        lastActiveTimes[event.sessionId] = now

                        val key = LogKey(event.sessionId, event.level)
                        val buffer = buffers.getOrPut(key) { LogBuffer() }
                        buffer.sb.append(event.text)
                        if (!event.text.contains('\n')) {
                            buffer.sb.append("\n")
                        }
                        buffer.lineCount++

                        if (buffer.lineCount % 50 == 0) {
                            Log.d(
                                "LogBridge",
                                "Buffered log: sessionId=${event.sessionId}, level=${event.level}, lines=${buffer.lineCount}"
                            )
                        }

                        // 如果 FFmpeg 錄影持續好幾個小時且不間斷噴日誌，純防抖會導致日誌永遠蓄積在記憶體中直到 OOM。
                        // 因此當單一緩衝達到 200 行時強制分段沖刷，兼顧防抖與記憶體安全。
                        if (buffer.lineCount >= 200) {
                            Log.d("LogBridge", "Buffer limit reached: Flushing sessionId=${event.sessionId}, level=${event.level}, lines=${buffer.lineCount}")
                            flushBuffer(key.sessionId, key.level, buffer)
                            buffers.remove(key)
                        }
                    }

                    is LogEvent.DebounceSweep -> {
                        if (lastActiveTimes.isNotEmpty()) {
                            val now = System.currentTimeMillis()
                            val timeIterator = lastActiveTimes.iterator()

                            while (timeIterator.hasNext()) {
                                val entry = timeIterator.next()
                                // 如果當前時間距離該會話最後活躍時間已超過 5000 毫秒
                                if (now - entry.value >= 5000) {
                                    // 判定該 sessionId 已經死線，將其旗下所有層級（INFO/ERROR）的緩衝全部收尾沖刷
                                    flushSession(entry.key, buffers)
                                    timeIterator.remove() // 移出活躍隊列
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 沖刷特定 sessionId 的所有殘留緩衝（收尾）
    private fun flushSession(sessionId: Long, buffers: HashMap<LogKey, LogBuffer>) {
        Log.d("LogBridge", "Debounce sweep: Flushing sessionId=$sessionId due to inactivity")
        val bufIterator = buffers.iterator()
        while (bufIterator.hasNext()) {
            val entry = bufIterator.next()
            if (entry.key.sessionId == sessionId) {
                flushBuffer(sessionId, entry.key.level, entry.value)
                bufIterator.remove() // 安全移除
            }
        }
    }

    private fun flushBuffer(sessionId: Long, level: Int, buffer: LogBuffer) {
        val text = buffer.sb.toString().trimEnd('\n')
        if (text.isNotEmpty()) {
            Log.d(
                "LogBridge",
                "Flushing log for sessionId=$sessionId, level=$level, lines=${buffer.lineCount}"
            )
            sendFFmpegLog(sessionId, level, text)
        }
    }

    fun enqueueLog(sessionId: Long, level: Int, message: String) {
        eventChannel.trySend(LogEvent.Allocate(sessionId, level, message))
    }
}