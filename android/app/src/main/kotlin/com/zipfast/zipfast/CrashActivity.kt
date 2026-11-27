package com.zipfast.zipfast

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

/**
 * Plain Android screen (no Flutter, no AndroidX) that shows the crash report. Runs in the
 * ":crash" process, so it works even when the main process cannot start.
 */
class CrashActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val report = intent.getStringExtra(CrashReporter.EXTRA_REPORT) ?: "(no details)"
        val pad = (16 * resources.displayMetrics.density).toInt()

        val title = TextView(this).apply {
            text = "ZipFast crashed\nZipFast가 종료되었습니다"
            textSize = 20f
            setTypeface(typeface, Typeface.BOLD)
        }
        val hint = TextView(this).apply {
            text = "Please send a screenshot of this screen.\n이 화면을 캡처해서 보내 주세요."
            setPadding(0, pad / 2, 0, pad / 2)
        }
        val details = TextView(this).apply {
            text = report
            textSize = 11f
            typeface = Typeface.MONOSPACE
            setTextIsSelectable(true)
        }
        val scroll = ScrollView(this).apply {
            addView(details)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
        }
        val copy = Button(this).apply {
            text = "Copy / 복사"
            setOnClickListener {
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("ZipFast crash", report))
                Toast.makeText(this@CrashActivity, "Copied / 복사했습니다", Toast.LENGTH_SHORT).show()
            }
        }
        val close = Button(this).apply {
            text = "Close / 닫기"
            setOnClickListener { finishAndRemoveTask() }
        }
        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.START
            addView(copy)
            addView(close)
        }
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad * 2, pad, pad)
            addView(title)
            addView(hint)
            addView(scroll)
            addView(buttons)
        })
    }
}
