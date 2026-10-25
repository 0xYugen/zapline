package app.zapline.player

import android.app.UiModeManager
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Lets the app hear phones looking for it on the network ("Send to TV"):
    // many devices drop broadcast packets without it.
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        multicastLock = (applicationContext.getSystemService(WIFI_SERVICE) as WifiManager)
            .createMulticastLock("zapline-cast")
            .apply {
                setReferenceCounted(false)
                acquire()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zapline/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Android TV, Google TV and Fire TV report television mode;
                    // leanback covers older TV boxes that don't.
                    "isTv" -> {
                        val uiMode = getSystemService(UI_MODE_SERVICE) as UiModeManager
                        result.success(
                            uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                                packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                        )
                    }
                    "deviceName" -> result.success(
                        Settings.Global.getString(contentResolver, "device_name")
                            ?: "${Build.MANUFACTURER} ${Build.MODEL}"
                    )
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        multicastLock?.release()
        super.onDestroy()
    }
}
