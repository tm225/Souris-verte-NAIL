package com.matrixlauncher.theme

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.View
import android.view.animation.OvershootInterpolator
import android.widget.PopupMenu
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.GridLayoutManager
import com.matrixlauncher.theme.databinding.ActivityMainBinding
import java.text.SimpleDateFormat
import java.util.*
import kotlin.random.Random

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var lockManager: LockManager
    private val clockHandler = Handler(Looper.getMainLooper())
    private var isUnlocked = false

    private val glyphPool = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%&$@!*".toCharArray()

    private val clockTick = object : Runnable {
        override fun run() {
            binding.clockText.text = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
            clockHandler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        lockManager = LockManager(this)

        binding.matrixRain.start()
        loadApps()

        binding.fingerprintIcon.setOnClickListener { requestUnlock() }
    }

    override fun onResume() {
        super.onResume()
        clockHandler.post(clockTick)
        if (!isUnlocked) {
            showLockOverlay(animateIn = false)
            requestUnlock()
        }
    }

    override fun onPause() {
        super.onPause()
        clockHandler.removeCallbacks(clockTick)
        // Reverrouille dès qu'on quitte l'écran d'accueil (retour d'une autre app, etc.)
        isUnlocked = false
    }

    override fun onBackPressed() {
        // Un launcher ne doit pas pouvoir être "quitté" par retour arrière
    }

    // ---------- Verrouillage / déverrouillage ----------

    private fun showLockOverlay(animateIn: Boolean) {
        binding.lockOverlay.visibility = View.VISIBLE
        binding.homeContent.visibility = View.INVISIBLE
        binding.decodeText.visibility = View.INVISIBLE
        binding.matrixRain.speedMultiplier = 1f
        if (animateIn) {
            binding.lockOverlay.alpha = 0f
            binding.lockOverlay.animate().alpha(1f).setDuration(250).start()
        } else {
            binding.lockOverlay.alpha = 1f
        }
    }

    private fun requestUnlock() {
        if (!lockManager.canUseFingerprint()) {
            Toast.makeText(this, "Aucune empreinte configurée sur cet appareil", Toast.LENGTH_LONG).show()
            return
        }
        lockManager.authenticate(
            onSuccess = { playUnlockAnimation() },
            onError = { /* l'utilisateur peut relancer via l'icône empreinte */ }
        )
    }

    /**
     * Animation de déverrouillage :
     * 1. Le fond Matrix accélère brutalement (effet "surcharge de données")
     * 2. Le texte se "décode" caractère par caractère jusqu'à afficher ACCÈS AUTORISÉ
     * 3. Léger glitch (secousse horizontale) sur l'icône
     * 4. Fondu + zoom vers l'écran d'accueil
     */
    private fun playUnlockAnimation() {
        isUnlocked = true

        // 1. Accélération du fond
        ValueAnimator.ofFloat(1f, 5f).apply {
            duration = 220
            addUpdateListener { binding.matrixRain.speedMultiplier = it.animatedValue as Float }
            start()
        }

        // Glitch : secousses horizontales rapides de l'icône
        ObjectAnimator.ofFloat(binding.fingerprintIcon, "translationX", 0f, -18f, 16f, -10f, 6f, 0f).apply {
            duration = 260
            start()
        }
        binding.fingerprintIcon.animate()
            .scaleX(1.3f).scaleY(1.3f)
            .setDuration(200)
            .setInterpolator(OvershootInterpolator())
            .start()

        // 2. Décodage du texte "ACCÈS AUTORISÉ"
        val finalText = getString(R.string.access_granted)
        binding.decodeText.visibility = View.VISIBLE
        decodeReveal(finalText) {
            // 4. Sortie de l'overlay
            Handler(Looper.getMainLooper()).postDelayed({
                binding.lockOverlay.animate()
                    .alpha(0f)
                    .scaleX(1.15f).scaleY(1.15f)
                    .setDuration(320)
                    .setListener(object : AnimatorListenerAdapter() {
                        override fun onAnimationEnd(animation: Animator) {
                            binding.lockOverlay.visibility = View.GONE
                            binding.lockOverlay.scaleX = 1f
                            binding.lockOverlay.scaleY = 1f
                            binding.matrixRain.speedMultiplier = 1f
                            revealHome()
                        }
                    })
                    .start()
            }, 350)
        }
    }

    /** Effet "hacker text" : chaque caractère scramble puis se fixe progressivement sur la bonne lettre. */
    private fun decodeReveal(finalText: String, onDone: () -> Unit) {
        val steps = 14
        var currentStep = 0
        val resolveAt = finalText.indices.map { Random.nextInt(steps / 2, steps) }

        val handler = Handler(Looper.getMainLooper())
        val runnable = object : Runnable {
            override fun run() {
                val sb = StringBuilder()
                for (i in finalText.indices) {
                    val c = finalText[i]
                    sb.append(
                        when {
                            c == ' ' -> ' '
                            currentStep >= resolveAt[i] -> c
                            else -> glyphPool[Random.nextInt(glyphPool.size)]
                        }
                    )
                }
                binding.decodeText.text = sb.toString()
                currentStep++
                if (currentStep <= steps) {
                    handler.postDelayed(this, 35)
                } else {
                    binding.decodeText.text = finalText
                    onDone()
                }
            }
        }
        handler.post(runnable)
    }

    private fun revealHome() {
        binding.homeContent.visibility = View.VISIBLE
        binding.homeContent.alpha = 0f
        binding.homeContent.translationY = 40f
        binding.homeContent.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(320)
            .start()
    }

    // ---------- Grille d'applications ----------

    private fun loadApps() {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)

        val apps = resolved
            .filter { it.activityInfo.packageName != packageName }
            .map {
                AppInfo(
                    label = it.loadLabel(pm).toString(),
                    packageName = it.activityInfo.packageName,
                    icon = it.loadIcon(pm)
                )
            }
            .distinctBy { it.packageName }
            .sortedBy { it.label.lowercase(Locale.getDefault()) }

        binding.appGrid.layoutManager = GridLayoutManager(this, 4)
        binding.appGrid.adapter = AppAdapter(
            apps,
            onClick = { app ->
                val launchIntent = pm.getLaunchIntentForPackage(app.packageName)
                if (launchIntent != null) startActivity(launchIntent)
            },
            onLongClick = { app, view -> showAppMenu(app, view) }
        )
    }

    private fun showAppMenu(app: AppInfo, anchor: View) {
        val popup = PopupMenu(this, anchor)
        popup.menu.add("Infos application")
        popup.setOnMenuItemClickListener {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:${app.packageName}")
            startActivity(intent)
            true
        }
        popup.show()
    }
}
