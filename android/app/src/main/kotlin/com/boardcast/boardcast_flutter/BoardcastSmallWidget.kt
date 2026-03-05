package com.boardcast.boardcast_flutter

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider

class BoardcastSmallWidget : GlanceAppWidget() {

    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { Content() }
    }

    @Composable
    fun Content() {
        val prefs = currentState<HomeWidgetGlanceState>().preferences
        val score = prefs.getInt("score", 0)
        val conditionLabel = prefs.getString("conditionLabel", "--") ?: "--"
        val locationName = prefs.getString("locationName", "") ?: ""
        val waveHeight = prefs.getString("waveHeight", "--") ?: "--"
        val windSpeed = prefs.getString("windSpeed", "--") ?: "--"

        val condColor = conditionColor(score)
        val bgColor = ColorProvider(android.graphics.Color.parseColor("#0f1923"))

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(12.dp)
                .background(bgColor)
                .cornerRadius(16.dp),
        ) {
            Column(
                modifier = GlanceModifier.fillMaxSize(),
                verticalAlignment = Alignment.Vertical.Top,
            ) {
                // Header: app name
                Text(
                    text = "Boardcast",
                    style = TextStyle(
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        color = ColorProvider(android.graphics.Color.parseColor("#8899aa")),
                    ),
                )

                Spacer(modifier = GlanceModifier.height(8.dp))

                // Score
                Text(
                    text = score.toString(),
                    style = TextStyle(
                        fontSize = 36.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(condColor),
                    ),
                )

                // Condition label
                Text(
                    text = conditionLabel,
                    style = TextStyle(
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = ColorProvider(condColor),
                    ),
                )

                Spacer(modifier = GlanceModifier.defaultWeight())

                // Wave + wind row
                Text(
                    text = "$waveHeight \u2022 $windSpeed",
                    style = TextStyle(
                        fontSize = 10.sp,
                        color = ColorProvider(android.graphics.Color.parseColor("#8899aa")),
                    ),
                )

                // Location
                if (locationName.isNotEmpty()) {
                    Text(
                        text = locationName,
                        style = TextStyle(
                            fontSize = 10.sp,
                            color = ColorProvider(android.graphics.Color.parseColor("#667788")),
                        ),
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

/** Map score (0-100) to condition color. */
fun conditionColor(score: Int): Int = when {
    score >= 80 -> android.graphics.Color.parseColor("#22c55e") // Epic
    score >= 60 -> android.graphics.Color.parseColor("#4db8a4") // Good
    score >= 40 -> android.graphics.Color.parseColor("#f59e0b") // Fair
    else -> android.graphics.Color.parseColor("#ef4444")         // Poor
}

/** Condition color with alpha for tint backgrounds. */
fun conditionColorWithAlpha(score: Int, alpha: Float): Int {
    val base = conditionColor(score)
    val a = (alpha * 255).toInt()
    return android.graphics.Color.argb(
        a,
        android.graphics.Color.red(base),
        android.graphics.Color.green(base),
        android.graphics.Color.blue(base),
    )
}
