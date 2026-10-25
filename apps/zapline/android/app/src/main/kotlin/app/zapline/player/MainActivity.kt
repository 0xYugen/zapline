package app.zapline.player

import android.app.UiModeManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
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
                    "installApk" -> result.success(
                        installApk(java.io.File(call.argument<String>("path")!!))
                    )
                    else -> result.notImplemented()
                }
            }
    }

    // An update downloaded by the app goes to Android's installer, which
    // asks to confirm. The first time, Android wants Zapline allowed to
    // install apps: its settings page opens and "permission" comes back.
    private fun installApk(apk: java.io.File): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName"),
                    )
                )
                return "permission"
            } catch (_: ActivityNotFoundException) {
                // Some TV systems have no such page: the installer explains.
            }
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
        startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
                )
        )
        return "started"
    }

    override fun onDestroy() {
        multicastLock?.release()
        super.onDestroy()
    }
}
