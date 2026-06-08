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
        // Gate the widget on auth: until a user signs in, render a locked card
        // and still route taps to Dart (which re-asserts the locked message).
        val loggedIn = widgetData.getBoolean("widget_logged_in", false)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.gate_widget)

            val open = widgetData.getBoolean("gate_open", false)
            // State/action text is localized in Dart (follows the app language)
            // and saved as widget data. Arabic defaults only show on first paint
            // before the Dart callback has run once.
            val state = widgetData.getString("gate_state", null)
                ?: if (open) "البوابة مفتوحة" else "البوابة مغلقة"
            val action = widgetData.getString("gate_action", null)
                ?: if (open) "اضغط للإغلاق" else "اضغط للفتح"
            // Locked status text comes from Dart (keyGateStatus) once signed out;
            // Arabic fallback covers the first paint before any Dart run.
            val status = widgetData.getString("gate_status", null)
                ?: if (loggedIn) "—" else "سجّل الدخول أولاً"

            if (loggedIn) {
                views.setTextViewText(R.id.gate_state, state)
                views.setTextViewText(R.id.gate_action, action)
                views.setImageViewResource(
                    R.id.gate_icon,
                    if (open) R.drawable.ic_gate_open else R.drawable.ic_gate_closed
                )
            } else {
                views.setTextViewText(R.id.gate_state, status)
                views.setTextViewText(R.id.gate_action, "")
                views.setImageViewResource(R.id.gate_icon, R.drawable.ic_gate_closed)
            }
            views.setTextViewText(R.id.gate_status, if (loggedIn) status else "")

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
