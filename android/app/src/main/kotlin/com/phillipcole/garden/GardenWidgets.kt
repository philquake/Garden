package com.phillipcole.garden

import android.app.PendingIntent
import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import org.json.JSONObject
import java.time.LocalDateTime

class Tile(val id: String, val name: String, val asset: String, val done: Boolean)

/** Reads what the Dart side saved (see lib/widget/widget_data.dart) and builds tiles. */
object Garden {
    fun prefs(c: Context) = c.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

    /** Same 03:00 rollover as lib/domain/day.dart. */
    private fun today() = LocalDateTime.now().minusHours(3).toLocalDate().toEpochDay().toInt()

    fun tiles(c: Context): List<Tile> {
        val s = prefs(c).getString("snapshot", null) ?: return emptyList()
        val o = JSONObject(s)
        // After the day changes the app has not yet re-evaluated "done".
        val fresh = o.getInt("day") == today()
        val a = o.getJSONArray("tiles")
        return List(a.length()) {
            val t = a.getJSONObject(it)
            Tile(t.getString("id"), t.getString("name"), t.getString("asset"), fresh && t.getBoolean("done"))
        }
    }

    /** Fills one tile: plant picture, done badge, tap to water. */
    fun bind(c: Context, rv: RemoteViews, slot: Int, plant: Int, badge: Int, t: Tile) {
        val bmp = c.assets.open("flutter_assets/assets/plants/${t.asset}.png").use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = 2 })
        }
        rv.setImageViewBitmap(plant, bmp)
        rv.setInt(plant, "setImageAlpha", if (t.done) 255 else 150)
        rv.setViewVisibility(badge, if (t.done) View.VISIBLE else View.GONE)
        rv.setContentDescription(slot, t.name + if (t.done) ", done today" else ", not done today")
        rv.setOnClickPendingIntent(slot, HomeWidgetBackgroundIntent.getBroadcast(c, Uri.parse("garden://tap?id=${Uri.encode(t.id)}")))
    }

    fun openApp(c: Context): PendingIntent = PendingIntent.getActivity(
        c, 0, c.packageManager.getLaunchIntentForPackage(c.packageName),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
