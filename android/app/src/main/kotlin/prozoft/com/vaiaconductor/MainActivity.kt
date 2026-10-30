package prozoft.com.vaiaconductor

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity es requerido por local_auth para la biometria.
class MainActivity : FlutterFragmentActivity() {
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
                    BubbleState.fecha = call.argument<String>("fecha") ?: "--/-- --:--:--"
                    call.argument<String>("dirDatos")?.let { if (it.isNotEmpty()) BubbleState.dirDatos = it }
                    if (canDrawOverlays()) {
                        try {
                            startService(Intent(this, OverlayBubbleService::class.java))
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "update" -> {
                    BubbleState.conectado = call.argument<Boolean>("conectado") ?: false
                    BubbleState.fecha = call.argument<String>("fecha") ?: "--/-- --:--:--"
                    call.argument<String>("dirDatos")?.let { if (it.isNotEmpty()) BubbleState.dirDatos = it }
                    result.success(true)
                }
                "hide" -> {
                    try {
                        stopService(Intent(this, OverlayBubbleService::class.java))
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "traerAlFrente" -> {
                    try {
                        val i = packageManager.getLaunchIntentForPackage(packageName)
                        i?.addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                        )
                        if (i != null) startActivity(i)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "moveToBack" -> {
                    try {
                        moveTaskToBack(true)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Notificaciones locales para mensajes/estatus cuando la app esta en
        // primer plano (FCM no las muestra por si solo en Android).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vaia/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        val title = call.argument<String>("title") ?: "Vaia Conductor"
                        val body = call.argument<String>("body") ?: ""
                        val id = call.argument<Int>("id")
                            ?: (System.currentTimeMillis() and 0x7FFFFFFF).toInt()
                        mostrarNotificacion(title, body, id)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun mostrarNotificacion(title: String, body: String, id: Int) {
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    "vaia_push",
                    "Vaia Conductor",
                    NotificationManager.IMPORTANCE_HIGH
                )
                channel.description = "Servicios y mensajes"
                manager.createNotificationChannel(channel)
            }

            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pending = PendingIntent.getActivity(this, id, intent, flags)

            val notificacion = NotificationCompat.Builder(this, "vaia_push")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pending)
                .build()

            manager.notify(id, notificacion)
        } catch (_: Exception) {
        }
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else true
    }
}
