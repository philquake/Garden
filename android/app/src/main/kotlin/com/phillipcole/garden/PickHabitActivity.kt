package com.phillipcole.garden

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.ListView
import android.widget.Toast

/** Configure screen of the 1x1 widget: pick which habit it waters. */
class PickHabitActivity : Activity() {
    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        setResult(RESULT_CANCELED)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return finish()
        val tiles = Garden.tiles(this)
        if (tiles.isEmpty()) {
            Toast.makeText(this, R.string.widget_no_habits, Toast.LENGTH_LONG).show()
            return finish()
        }
        title = getString(R.string.widget_pick)
        val list = ListView(this)
        list.adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, tiles.map { it.name })
        list.setOnItemClickListener { _, _, i, _ ->
            Garden.prefs(this).edit().putString("habit_$id", tiles[i].id).apply()
            SingleWidgetProvider.update(this, AppWidgetManager.getInstance(this), id)
            setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
            finish()
        }
        setContentView(list)
    }
}
