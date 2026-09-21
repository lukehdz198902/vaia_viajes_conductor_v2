package prozoft.com.vaiaconductor

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Outline
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/** Estado compartido entre Flutter (MainActivity) y la burbuja. */
object BubbleState {
    @Volatile var conectado: Boolean = false
    @Volatile var fecha: String = "--/-- --:--:--"
    @Volatile var dirDatos: String = ""
}

/**
 * Burbuja flotante circular con el logotipo de Vaia. Se muestra solo al
 * minimizar/cerrar la app. Incluye un punto verde (conectado) o gris
 * (desconectado) y la fecha/hora de la ultima ubicacion enviada al servidor.
 */
class OverlayBubbleService : Service() {

    private lateinit var windowManager: WindowManager
    private var bubbleView: View? = null
    private var dotView: View? = null
    private var timeView: TextView? = null
    private val handler = Handler(Looper.getMainLooper())

    private val ticker = object : Runnable {
        override fun run() {
            actualizar()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        crearBurbuja()
        handler.post(ticker)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun crearBurbuja() {
        if (bubbleView != null) return

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP or Gravity.START
        lp.x = dp(20)
        lp.y = dp(220)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }

        val circle = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(64), dp(64))
        }

        val logo = ImageView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setImageResource(R.drawable.vaia_bubble_logo)
            scaleType = ImageView.ScaleType.CENTER_CROP
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.WHITE)
                setStroke(dp(3), Color.parseColor("#F59E0B"))
            }
            clipToOutline = true
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    outline.setOval(0, 0, view.width, view.height)
                }
            }
            elevation = dp(8).toFloat()
        }

        dotView = View(this).apply {
            val size = dp(18)
            layoutParams = FrameLayout.LayoutParams(size, size).apply {
                gravity = Gravity.BOTTOM or Gravity.END
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#94A3B8"))
                setStroke(dp(2), Color.WHITE)
            }
        }

        circle.addView(logo)
        circle.addView(dotView)

        timeView = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(6) }
            setTextColor(Color.WHITE)
            textSize = 10f
            gravity = Gravity.CENTER
            text = "--/-- --:--:--"
            setPadding(dp(8), dp(3), dp(8), dp(3))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(20).toFloat()
                setColor(Color.parseColor("#E60F172A"))
            }
        }

        root.addView(circle)
        root.addView(timeView)

        var iniX = 0
        var iniY = 0
        var toqueX = 0f
        var toqueY = 0f
        var arrastro = false
        root.setOnTouchListener { _, ev ->
            when (ev.action) {
                MotionEvent.ACTION_DOWN -> {
                    iniX = lp.x
                    iniY = lp.y
                    toqueX = ev.rawX
                    toqueY = ev.rawY
                    arrastro = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (ev.rawX - toqueX).toInt()
                    val dy = (ev.rawY - toqueY).toInt()
                    if (Math.abs(dx) > dp(4) || Math.abs(dy) > dp(4)) arrastro = true
                    lp.x = iniX + dx
                    lp.y = iniY + dy
                    try { windowManager.updateViewLayout(root, lp) } catch (_: Exception) {}
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!arrastro) abrirApp()
                    true
                }
                else -> false
            }
        }

        bubbleView = root
        try {
            windowManager.addView(root, lp)
        } catch (_: Exception) {
            bubbleView = null
        }
    }

    private fun abrirApp() {
        try {
            val i = packageManager.getLaunchIntentForPackage(packageName)
            i?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            if (i != null) startActivity(i)
        } catch (_: Exception) {}
    }

    /**
     * Lee el estado que escribe el servicio en primer plano de Flutter
     * (formato "conectado|dd/MM HH:mm:ss"). Asi la burbuja refleja la ultima
     * ubicacion enviada aunque la app este minimizada.
     */
    private fun leerArchivoEstado(): Pair<Boolean, String>? {
        val dir = BubbleState.dirDatos
        if (dir.isEmpty()) return null
        return try {
            val f = java.io.File(dir, "vaia_estado_ubicacion.txt")
            if (!f.exists()) return null
            val partes = f.readText().trim().split("|")
            if (partes.size < 2) null else Pair(partes[0] == "1", partes[1])
        } catch (_: Exception) {
            null
        }
    }

    private fun actualizar() {
        val archivo = leerArchivoEstado()
        val conectado = archivo?.first ?: BubbleState.conectado
        val fecha = archivo?.second ?: BubbleState.fecha
        val color = if (conectado) "#10B981" else "#94A3B8"
        (dotView?.background as? GradientDrawable)?.setColor(Color.parseColor(color))
        timeView?.text = fecha
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        bubbleView?.let {
            try { windowManager.removeView(it) } catch (_: Exception) {}
        }
        bubbleView = null
        super.onDestroy()
    }
}
