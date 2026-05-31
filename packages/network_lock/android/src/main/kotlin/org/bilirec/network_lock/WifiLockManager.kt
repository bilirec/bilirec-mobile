package org.bilirec.network_lock

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log

class WifiLockManager(context: Context) {
    private val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private var wifiLock: WifiManager.WifiLock? = null

    val isLocked: Boolean
        get() = wifiLock?.isHeld == true

    fun acquireHighPerfLock() {
        if (isLocked) return

        // 根據系統版本選用對應的 Lock 模式
        val lockMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10 (API 29) 以上：使用低延遲模式
            WifiManager.WIFI_MODE_FULL_LOW_LATENCY
        } else {
            // Android 10 以下：使用過時但有效的 High Perf 模式
            // 註：WIFI_MODE_FULL_HIGH_PERF 的數值在底層就是 3
            WifiManager.WIFI_MODE_FULL_HIGH_PERF
        }

        if (wifiLock == null) {
            wifiLock = wifiManager.createWifiLock(lockMode, "Bilirec:HighPerfLock")
            wifiLock?.setReferenceCounted(false) // 設置為不計數，保證呼叫一次就鎖定
        }

        if (wifiLock?.isHeld == false) {
            wifiLock?.acquire()
            Log.d("WifiLockManager", "高性能 Wifi 鎖定已啓動")
        }
    }

    fun releaseHighPerfLock() {
        if (!isLocked) return
        wifiLock?.release()
        Log.d("WifiLockManager", "高性能 Wifi 鎖定已釋放")
    }
}