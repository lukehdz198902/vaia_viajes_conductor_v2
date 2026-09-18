package prozoft.com.vaiaconductor

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/** Estado compartido entre Flutter (MainActivity) y la burbuja. */
object BubbleState {
    @Volatile var conectado: Boolean = false
    @Volatile var ultima: String = "--:--:--"
}

/**
 * Burbuja flotante (overlay) que se muestra al minimizar la app del conductor.
 * Muestra un punto verde si esta conectado, gris si no, y la hora de la
 * ultima ubicacion enviada al servidor.
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
        lp.x = 40
        lp.y = 260

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(26, 18, 26, 18)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.parseColor("#E60F172A"))
                cornerRadius = 70f
                setStroke(2, Color.parseColor("#33FFFFFF"))
            }
            elevation = 14f
        }

        dotView = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(30, 30).apply { gravity = Gravity.CENTER_HORIZONTAL }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#94A3B8"))
            }
        }

        timeView = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 11f
            gravity = Gravity.CENTER
            text = "--:--:--"
            setPadding(0, 8, 0, 0)
        }

        root.addView(dotView)
        root.addView(timeView)

        // Arrastrar la burbuja
        var iniX = 0
        var iniY = 0
        var toqueX = 0f
        var toqueY = 0f
        root.setOnTouchListener { _, ev ->
            when (ev.action) {
                MotionEvent.ACTION_DOWN -> {
                    iniX = lp.x
                    iniY = lp.y
                    toqueX = ev.rawX
                    toqueY = ev.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    lp.x = iniX + (ev.rawX - toqueX).toInt()
                    lp.y = iniY + (ev.rawY - toqueY).toInt()
                    try { windowManager.updateViewLayout(root, lp) } catch (_: Exception) {}
                    true
                }
                else -> false
            }
        }

        // Tocar para abrir la app
        root.setOnClickListener {
            try {
                val i = packageManager.getLaunchIntentForPackage(packageName)
                i?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                if (i != null) startActivity(i)
            } catch (_: Exception) {}
        }

        bubbleView = root
        try {
            windowManager.addView(root, lp)
        } catch (_: Exception) {
            bubbleView = null
        }
    }

    private fun actualizar() {
        val color = if (BubbleState.conectado) "#10B981" else "#94A3B8"
        (dotView?.background as? GradientDrawable)?.setColor(Color.parseColor(color))
        timeView?.text = BubbleState.ultima
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
