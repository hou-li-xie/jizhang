package com.jizhang.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** 桌面小组件：展示本月支出与收入总额。 */
class JizhangWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("jizhang_widget", Context.MODE_PRIVATE)
            val expense = prefs.getString("expense", "0.00") ?: "0.00"
            val income = prefs.getString("income", "0.00") ?: "0.00"

            val views = RemoteViews(context.packageName, R.layout.widget_jizhang)
            views.setTextViewText(R.id.widget_expense, "¥$expense")
            views.setTextViewText(R.id.widget_income, "¥$income")

            // 点击小组件打开 App
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
