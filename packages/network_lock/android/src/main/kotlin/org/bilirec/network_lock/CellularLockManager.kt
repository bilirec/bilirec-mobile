package org.bilirec.network_lock

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log

class CellularLockManager(context: Context) {
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    // 用來記錄當前是否已鎖定
    var isLocked: Boolean = false
        private set

    fun acquireCellularLock() {
        if (networkCallback != null || isLocked) return

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                super.onAvailable(network)
                isLocked = true
                Log.d("BiliRec:Cellular", "移動網路鎖定已啓動")
            }

            override fun onLost(network: Network) {
                super.onLost(network)
                isLocked = false
                Log.w("BiliRec:Cellular", "移動網路已斷開，鎖定已失效")
            }
        }

        connectivityManager.requestNetwork(request, networkCallback!!)
    }

    fun releaseCellularLock() {
        networkCallback?.let {
            try {
                connectivityManager.unregisterNetworkCallback(it)
            } finally {
                networkCallback = null
                isLocked = false
                Log.d("BiliRec:Cellular", "移動網路鎖定已釋放")
            }
        }
    }
}