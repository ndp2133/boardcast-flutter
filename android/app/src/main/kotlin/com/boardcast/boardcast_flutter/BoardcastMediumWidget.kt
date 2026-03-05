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
import org.json.JSONArray

class BoardcastMediumWidget : GlanceAppWidget() {

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
        val hourlyJson = prefs.getString("hourlyScores", "[]") ?: "[]"
        val bestStart = prefs.getString("bestWindowStart", "") ?: ""
        val bestEnd = prefs.getString("bestWindowEnd", "") ?: ""
        val bestLabel = prefs.getString("bestWindowLabel", "") ?: ""

        val condColor = conditionColor(score)
        val bgColor = ColorProvider(android.graphics.Color.parseColor("#0f1923"))

        // Parse hourly scores
        val hourlyScores = parseHourlyScores(hourlyJson)

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(12.dp)
                .background(bgColor)
                .cornerRadius(16.dp),
        ) {
            Column(modifier = GlanceModifier.fillMaxSize()) {
                // Header: location + score + condition
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Vertical.CenterVertically,
                ) {
                    Column(modifier = GlanceModifier.defaultWeight()) {
                        Text(
                            text = locationName.ifEmpty { "Boardcast" },
                            style = TextStyle(
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Medium,
                                color = ColorProvider(android.graphics.Color.parseColor("#8899aa")),
                            ),
                            maxLines = 1,
                        )
                        Row(verticalAlignment = Alignment.Vertical.Bottom) {
                            Text(
                                text = score.toString(),
                                style = TextStyle(
                                    fontSize = 28.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = ColorProvider(condColor),
                                ),
                            )
                            Spacer(modifier = GlanceModifier.width(6.dp))
                            Text(
                                text = conditionLabel,
                                style = TextStyle(
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = ColorProvider(condColor),
                                ),
                            )
                        }
                    }
                    // Wave + wind
                    Column(horizontalAlignment = Alignment.Horizontal.End) {
                        Text(
                            text = waveHeight,
                            style = TextStyle(
                                fontSize = 11.sp,
                                color = ColorProvider(android.graphics.Color.parseColor("#8899aa")),
                            ),
                        )
                        Text(
                            text = windSpeed,
                            style = TextStyle(
                                fontSize = 11.sp,
                                color = ColorProvider(android.graphics.Color.parseColor("#8899aa")),
                            ),
                        )
                    }
                }

                Spacer(modifier = GlanceModifier.height(8.dp))

                // Score bar chart — row of colored columns
                if (hourlyScores.isNotEmpty()) {
                    Row(
                        modifier = GlanceModifier.fillMaxWidth(),
                        verticalAlignment = Alignment.Vertical.Bottom,
                    ) {
                        val maxBars = minOf(hourlyScores.size, 12)
                        // Dynamic scaling: find min/max of visible scores
                        val visibleScores = hourlyScores.take(maxBars).map { it.score }
                        val rawMin = (visibleScores.minOrNull() ?: 0).toDouble()
                        val rawMax = (visibleScores.maxOrNull() ?: 100).toDouble()
                        val span = rawMax - rawMin
                        val rangeMin = if (span >= 20) maxOf(0.0, rawMin - 15) else maxOf(0.0, (rawMin + rawMax) / 2 - 25)
                        val rangeMax = if (span >= 20) minOf(100.0, rawMax + 15) else minOf(100.0, (rawMin + rawMax) / 2 + 25)
                        val rangeSpan = maxOf(rangeMax - rangeMin, 1.0)
                        val maxBarHeight = 40 // max bar height in dp

                        for (i in 0 until maxBars) {
                            val entry = hourlyScores[i]
                            val normalized = (entry.score.toDouble() - rangeMin) / rangeSpan
                            val barHeight = maxOf((normalized * maxBarHeight).toInt(), 4)
                            val barColor = conditionColor(entry.score)
                            Column(
                                modifier = GlanceModifier.defaultWeight(),
                                horizontalAlignment = Alignment.Horizontal.CenterHorizontally,
                            ) {
                                Box(
                                    modifier = GlanceModifier
                                        .width(6.dp)
                                        .height(barHeight.dp)
                                        .background(ColorProvider(barColor))
                                        .cornerRadius(3.dp),
                                ) {}
                                Spacer(modifier = GlanceModifier.height(2.dp))
                                // Show hour label for every 3rd bar
                                if (i % 3 == 0) {
                                    Text(
                                        text = formatHour(entry.hour),
                                        style = TextStyle(
                                            fontSize = 8.sp,
                                            color = ColorProvider(
                                                android.graphics.Color.parseColor("#667788"),
                                            ),
                                        ),
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = GlanceModifier.defaultWeight())

                // Best window pill
                if (bestLabel.isNotEmpty() && bestStart.isNotEmpty()) {
                    val windowText = formatBestWindow(bestStart, bestEnd, bestLabel)
                    Text(
                        text = windowText,
                        style = TextStyle(
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Medium,
                            color = ColorProvider(android.graphics.Color.parseColor("#4db8a4")),
                        ),
                    )
                }
            }
        }
    }

    private fun formatHour(hour: Int): String {
        return when {
            hour == 0 -> "12a"
            hour < 12 -> "${hour}a"
            hour == 12 -> "12p"
            else -> "${hour - 12}p"
        }
    }

    private fun formatBestWindow(start: String, end: String, label: String): String {
        return try {
            val startHour = start.substring(11, 13).toIntOrNull() ?: return "$label window"
            val endHour = end.substring(11, 13).toIntOrNull() ?: return "$label window"
            "$label \u2022 ${formatHour(startHour)}-${formatHour(endHour)}"
        } catch (_: Exception) {
            "$label window"
        }
    }
}

data class HourlyEntry(val hour: Int, val score: Int)

fun parseHourlyScores(json: String): List<HourlyEntry> {
    return try {
        val arr = JSONArray(json)
        (0 until arr.length()).map { i ->
            val obj = arr.getJSONObject(i)
            HourlyEntry(
                hour = obj.getInt("h"),
                score = obj.getInt("s"),
            )
        }
    } catch (_: Exception) {
        emptyList()
    }
}
