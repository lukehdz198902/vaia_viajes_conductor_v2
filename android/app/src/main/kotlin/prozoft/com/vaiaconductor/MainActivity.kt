package prozoft.com.vaiaconductor

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "vaia/bubble"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> {
                    result.success(canDrawOverlays())
                }
                "requestPermission" -> {
                    try {
                        val i = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "show" -> {
                    BubbleState.conectado = call.argument<Boolean>("conectado") ?: false
                    BubbleState.ultima = call.argument<String>("ultima") ?: "--:--:--"
                    if (canDrawOverlays()) {
                        try {
                            startService(Intent(this, OverlayBubbleService::class.java))
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "update" -> {
                    BubbleState.conectado = call.argument<Boolean>("conectado") ?: false
                    BubbleState.ultima = call.argument<String>("ultima") ?: "--:--:--"
                    result.success(true)
                }
                "hide" -> {
                    try {
                        stopService(Intent(this, OverlayBubbleService::class.java))
                    } catch (_: Exception) {}
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else true
    }
}
