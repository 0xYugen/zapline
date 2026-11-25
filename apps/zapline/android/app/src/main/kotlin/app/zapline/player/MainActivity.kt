package app.zapline.player

import android.app.PictureInPictureParams
import android.app.UiModeManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.AudioManager
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import android.util.Rational
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Lets the app hear phones looking for it on the network ("Send to TV"):
    // many devices drop broadcast packets without it.
    private var multicastLock: WifiManager.MulticastLock? = null

    private var channel: MethodChannel? = null

    // Picture-in-picture while a player is open on a phone: the picture's
    // shape, or null when leaving the app should just leave it.
    private var pipAspect: Rational? = null

    // TVs draw with Skia: Impeller shows broken pictures and stalls on the
    // PowerVR graphics of Fire TV sticks and many TV boxes (flutter/181315),
    // and a TV's simple screens don't need it.
    override fun getFlutterShellArgs(): FlutterShellArgs {
        val args = super.getFlutterShellArgs()
        if (isTv()) args.add(FlutterShellArgs.ARG_DISABLE_IMPELLER)
        return args
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        multicastLock = (applicationContext.getSystemService(WIFI_SERVICE) as WifiManager)
            .createMulticastLock("zapline-cast")
            .apply {
                setReferenceCounted(false)
                acquire()
            }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zapline/device")
        channel!!.setMethodCallHandler { call, result ->
                when (call.method) {
                    // The player's own window brightness, 0–1 (the system's
                    // while it has none); null follows the system again.
                    // Nothing else on the phone changes.
                    "brightness" -> {
                        val b = window.attributes.screenBrightness
                        result.success(
                            if (b >= 0) b.toDouble()
                            else Settings.System.getInt(
                                contentResolver,
                                Settings.System.SCREEN_BRIGHTNESS,
                                128,
                            ) / 255.0
                        )
                    }
                    "setBrightness" -> {
                        val v = call.argument<Double>("value")
                        val attrs = window.attributes
                        attrs.screenBrightness = v?.toFloat()?.coerceIn(0.01f, 1f)
                            ?: android.view.WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                        window.attributes = attrs
                        result.success(null)
                    }
                    // Media volume, 0–1, as the volume keys set it.
                    "volume" -> {
                        val am = getSystemService(AUDIO_SERVICE) as AudioManager
                        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        result.success(
                            am.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
                        )
                    }
                    "setVolume" -> {
                        val am = getSystemService(AUDIO_SERVICE) as AudioManager
                        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val v = (call.argument<Double>("value") ?: 0.0).coerceIn(0.0, 1.0)
                        // No system slider: the player shows its own.
                        am.setStreamVolume(
                            AudioManager.STREAM_MUSIC,
                            Math.round(v * max).toInt(),
                            0,
                        )
                        result.success(null)
                    }
                    "setPip" -> {
                        val w = call.argument<Int>("width") ?: 0
                        val h = call.argument<Int>("height") ?: 0
                        pipAspect = if (call.argument<Boolean>("enabled") == true &&
                            !isTv() && w > 0 && h > 0
                        ) Rational(w, h) else null
                        updatePip()
                        result.success(pipSupported())
                    }
                    "isTv" -> result.success(isTv())
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

    // Android TV and Google TV report television mode; leanback covers older
    // TV boxes that don't, and Fire TV is told apart by Amazon's own feature
    // and its model names ("AFT…"), as not every Fire OS reports either.
    private fun isTv(): Boolean {
        val uiMode = getSystemService(UI_MODE_SERVICE) as UiModeManager
        return uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            packageManager.hasSystemFeature("android.hardware.type.television") ||
            packageManager.hasSystemFeature("amazon.hardware.fire_tv") ||
            Build.MODEL.startsWith("AFT")
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

    private fun pipSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    // Android's extremes: wider than 2.39:1 or taller than 1:2.39 is refused.
    private fun pipParams(aspect: Rational): PictureInPictureParams {
        val clamped = when {
            aspect.toFloat() > 2.39f -> Rational(239, 100)
            aspect.toFloat() < 1 / 2.39f -> Rational(100, 239)
            else -> aspect
        }
        val b = PictureInPictureParams.Builder().setAspectRatio(clamped)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: going home shrinks the player smoothly by itself.
            b.setAutoEnterEnabled(true).setSeamlessResizeEnabled(true)
        }
        return b.build()
    }

    private fun updatePip() {
        if (!pipSupported()) return
        val aspect = pipAspect
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setPictureInPictureParams(
                if (aspect != null) pipParams(aspect)
                else PictureInPictureParams.Builder().setAutoEnterEnabled(false).build()
            )
        }
    }

    // Before Android 12 the app enters picture-in-picture itself when the
    // user leaves (Home, recent apps) while a player is open.
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        val aspect = pipAspect ?: return
        if (pipSupported() && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            try {
                enterPictureInPictureMode(pipParams(aspect))
            } catch (_: IllegalStateException) {
                // Turned off for this app in the system settings.
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channel?.invokeMethod("pip", isInPictureInPictureMode)
    }

    override fun onDestroy() {
        multicastLock?.release()
        super.onDestroy()
    }
}
