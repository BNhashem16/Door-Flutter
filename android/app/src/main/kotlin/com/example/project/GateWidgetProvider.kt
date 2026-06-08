package com.example.project

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen gate widget. Renders the last-saved gate state (written by the
 * Dart background callback) and routes the button tap back into Dart via a
 * HomeWidget background intent — no Activity / app launch.
 */
class GateWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.gate_widget)

            val open = widgetData.getBoolean("gate_open", false)
            val status = widgetData.getString("gate_status", "—") ?: "—"

            views.setTextViewText(
                R.id.gate_state,
                if (open) "البوابة مفتوحة" else "البوابة مغلقة"
            )
            views.setTextViewText(
                R.id.gate_action,
                if (open) "اضغط للإغلاق" else "اضغط للفتح"
            )
            views.setTextViewText(R.id.gate_status, status)
            views.setImageViewResource(
                R.id.gate_icon,
                if (open) R.drawable.ic_gate_open else R.drawable.ic_gate_closed
            )

            // Tap → Dart `gateWidgetTapped` with doorwidget://toggle
            val intent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("doorwidget://toggle")
            )
            views.setOnClickPendingIntent(R.id.gate_button, intent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
