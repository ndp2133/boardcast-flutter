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

        val trend = prefs.getString("trend", "\u2192") ?: "\u2192"

        val condColor = conditionColor(score)
        val bgColor = ColorProvider(android.graphics.Color.parseColor("#0f1923"))

        // Condition-tinted background
        val tintColor = ColorProvider(conditionColorWithAlpha(score, 0.12f))

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(12.dp)
                .background(tintColor)
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

                // Condition label + trend
                Row(verticalAlignment = Alignment.Vertical.CenterVertically) {
                    Text(
                        text = conditionLabel,
                        style = TextStyle(
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                            color = ColorProvider(condColor),
                        ),
                    )
                    Spacer(modifier = GlanceModifier.width(4.dp))
                    Text(
                        text = trend,
                        style = TextStyle(
                            fontSize = 13.sp,
                            color = ColorProvider(condColor),
                        ),
                    )
                }

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
    score >= 80 -> android.graphics.Color.parseColor("#2e8a5e") // Epic — sage
    score >= 60 -> android.graphics.Color.parseColor("#3d9189") // Good — sea-glass
    score >= 40 -> android.graphics.Color.parseColor("#b07a4f") // Fair — sand
    else -> android.graphics.Color.parseColor("#9e5e5e")         // Poor — brick
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
