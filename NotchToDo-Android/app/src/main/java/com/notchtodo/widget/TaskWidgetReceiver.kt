package com.notchtodo.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import com.notchtodo.util.DebugLog

/**
 * Widget provider for NotchToDo tasks widget.
 * TODO: Implement Glance-based widget when needed.
 */
class TaskWidgetReceiver : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        DebugLog.log("Widget update requested", DebugLog.Category.UI)
        // TODO: Implement widget update using Jetpack Glance
    }
}
