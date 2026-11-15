package com.phillipcole.garden

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * 1x4 widget: up to four habit tiles. shortcut: Android widgets cannot scroll
 * horizontally, so with more than four habits the arrows move the window; swap
 * for a vertically scrolling grid only if this proves too clumsy.
 */
class RowWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(c: Context, m: AppWidgetManager, ids: IntArray) = ids.forEach { update(c, m, it) }

    override fun onDeleted(c: Context, ids: IntArray) {
        val e = Garden.prefs(c).edit()
        ids.forEach { e.remove("start_$it") }
        e.apply()
    }

    override fun onReceive(c: Context, intent: Intent) {
        super.onReceive(c, intent)
        if (intent.action != PAGE) return
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, 0)
        val p = Garden.prefs(c)
        p.edit().putInt("start_$id", p.getInt("start_$id", 0) + intent.getIntExtra("delta", 0)).apply()
        update(c, AppWidgetManager.getInstance(c), id)
    }

    companion object {
        const val PAGE = "com.phillipcole.garden.PAGE"
        private val slots = intArrayOf(R.id.slot0, R.id.slot1, R.id.slot2, R.id.slot3)
        private val plants = intArrayOf(R.id.plant0, R.id.plant1, R.id.plant2, R.id.plant3)
        private val badges = intArrayOf(R.id.badge0, R.id.badge1, R.id.badge2, R.id.badge3)

        private fun nav(c: Context, id: Int, delta: Int) = PendingIntent.getBroadcast(
            c, id * 2 + (if (delta > 0) 1 else 0),
            Intent(c, RowWidgetProvider::class.java).setAction(PAGE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id).putExtra("delta", delta),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        fun update(c: Context, m: AppWidgetManager, id: Int) {
            val all = Garden.tiles(c)
            val maxStart = maxOf(0, all.size - 4)
            val start = Garden.prefs(c).getInt("start_$id", 0).coerceIn(0, maxStart)
            val shown = all.drop(start).take(4)
            val rv = RemoteViews(c.packageName, R.layout.widget_row)
            // Unused slots are GONE; the row centres what is left.
            for (i in 0..3) {
                if (i < shown.size) {
                    rv.setViewVisibility(slots[i], View.VISIBLE)
                    Garden.bind(c, rv, slots[i], plants[i], badges[i], shown[i])
                } else rv.setViewVisibility(slots[i], View.GONE)
            }
            rv.setViewVisibility(R.id.empty, if (all.isEmpty()) View.VISIBLE else View.GONE)
            rv.setOnClickPendingIntent(R.id.empty, Garden.openApp(c))
            rv.setViewVisibility(R.id.prev, if (start > 0) View.VISIBLE else View.GONE)
            rv.setViewVisibility(R.id.next, if (start < maxStart) View.VISIBLE else View.GONE)
            rv.setOnClickPendingIntent(R.id.prev, nav(c, id, -minOf(4, start).coerceAtLeast(1)))
            rv.setOnClickPendingIntent(R.id.next, nav(c, id, minOf(4, maxStart - start).coerceAtLeast(1)))
            m.updateAppWidget(id, rv)
        }
    }
}
