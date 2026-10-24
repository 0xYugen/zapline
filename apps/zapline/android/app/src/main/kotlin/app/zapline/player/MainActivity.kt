package app.zapline.player

import android.app.UiModeManager
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                    else -> result.notImplemented()
                }
            }
    }
}
