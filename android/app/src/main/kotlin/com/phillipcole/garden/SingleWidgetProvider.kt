package com.phillipcole.garden

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/** 1x1 widget: one habit, chosen in [PickHabitActivity]. */
class SingleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(c: Context, m: AppWidgetManager, ids: IntArray) = ids.forEach { update(c, m, it) }

    override fun onDeleted(c: Context, ids: IntArray) {
        val e = Garden.prefs(c).edit()
        ids.forEach { e.remove("habit_$it") }
        e.apply()
    }

    companion object {
        fun update(c: Context, m: AppWidgetManager, id: Int) {
            val rv = RemoteViews(c.packageName, R.layout.widget_single)
            val tile = Garden.prefs(c).getString("habit_$id", null)
                ?.let { habit -> Garden.tiles(c).firstOrNull { it.id == habit } }
            if (tile == null) {
                // Not chosen yet, or the habit was deleted: tapping lets the user pick.
                rv.setImageViewBitmap(R.id.plant, null)
                rv.setViewVisibility(R.id.badge, View.GONE)
                rv.setViewVisibility(R.id.hint, View.VISIBLE)
                rv.setOnClickPendingIntent(R.id.slot, PendingIntent.getActivity(
                    c, id, Intent(c, PickHabitActivity::class.java).putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ))
            } else {
                rv.setViewVisibility(R.id.hint, View.GONE)
                Garden.bind(c, rv, R.id.slot, R.id.plant, R.id.badge, tile)
            }
            m.updateAppWidget(id, rv)
        }
    }
}
