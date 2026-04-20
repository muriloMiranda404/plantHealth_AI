package com.example.plant_disease_gui

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PlantGuardWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.plant_guard_widget).apply {
                val status = widgetData.getString("widget_status", "Status: OK")
                val temp = widgetData.getString("widget_temp", "--")
                val hum = widgetData.getString("widget_hum", "--")
                
                setTextViewText(R.id.widget_status, status)
                setTextViewText(R.id.widget_temp, temp)
                setTextViewText(R.id.widget_hum, hum)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
