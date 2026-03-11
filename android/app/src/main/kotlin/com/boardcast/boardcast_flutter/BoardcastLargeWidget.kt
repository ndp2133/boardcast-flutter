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

class BoardcastLargeWidget : GlanceAppWidget() {

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
        val waveJson = prefs.getString("hourlyWaveHeights", "[]") ?: "[]"
        val windowsJson = prefs.getString("upcomingWindows", "[]") ?: "[]"
        val bestStart = prefs.getString("bestWindowStart", "") ?: ""
        val bestEnd = prefs.getString("bestWindowEnd", "") ?: ""
        val bestScore = prefs.getInt("bestWindowScore", 0)
        val bestLabel = prefs.getString("bestWindowLabel", "") ?: ""

        val trend = prefs.getString("trend", "\u2192") ?: "\u2192"

        val condColor = conditionColor(score)
        val bgColor = ColorProvider(android.graphics.Color.parseColor("#0f1923"))
        val teal = android.graphics.Color.parseColor("#3d9189")
        val subTextColor = android.graphics.Color.parseColor("#8899aa")
        val lightColor = android.graphics.Color.parseColor("#e2e8f0")

        val hourlyScores = parseHourlyScores(hourlyJson)
        val waveHeights = parseWaveHeights(waveJson)
        val upcomingWindows = parseUpcomingWindows(windowsJson)

        // Condition-tinted background
        val tintColor = ColorProvider(conditionColorWithAlpha(score, 0.08f))

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(12.dp)
                .background(tintColor)
                .cornerRadius(16.dp),
        ) {
            Column(modifier = GlanceModifier.fillMaxSize()) {
                // 1. Header: location + score + condition
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
                                color = ColorProvider(subTextColor),
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
                            Spacer(modifier = GlanceModifier.width(3.dp))
                            Text(
                                text = trend,
                                style = TextStyle(
                                    fontSize = 12.sp,
                                    color = ColorProvider(condColor),
                                ),
                            )
                        }
                    }
                    Column(horizontalAlignment = Alignment.Horizontal.End) {
                        Text(
                            text = waveHeight,
                            style = TextStyle(fontSize = 11.sp, color = ColorProvider(subTextColor)),
                        )
                        Text(
                            text = windSpeed,
                            style = TextStyle(fontSize = 11.sp, color = ColorProvider(subTextColor)),
                        )
                    }
                }

                Spacer(modifier = GlanceModifier.height(8.dp))

                // 2. Score bar chart (18hr)
                if (hourlyScores.isNotEmpty()) {
                    Row(
                        modifier = GlanceModifier.fillMaxWidth(),
                        verticalAlignment = Alignment.Vertical.Bottom,
                    ) {
                        val maxBars = minOf(hourlyScores.size, 18)
                        val visibleScores = hourlyScores.take(maxBars).map { it.score }
                        val rawMin = (visibleScores.minOrNull() ?: 0).toDouble()
                        val rawMax = (visibleScores.maxOrNull() ?: 100).toDouble()
                        val span = rawMax - rawMin
                        val rangeMin = if (span >= 20) maxOf(0.0, rawMin - 15) else maxOf(0.0, (rawMin + rawMax) / 2 - 25)
                        val rangeMax = if (span >= 20) minOf(100.0, rawMax + 15) else minOf(100.0, (rawMin + rawMax) / 2 + 25)
                        val rangeSpan = maxOf(rangeMax - rangeMin, 1.0)
                        val maxBarHeight = 50

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
                                        .width(4.dp)
                                        .height(barHeight.dp)
                                        .background(ColorProvider(barColor))
                                        .cornerRadius(2.dp),
                                ) {}
                                Spacer(modifier = GlanceModifier.height(2.dp))
                                if (i % 3 == 0) {
                                    Text(
                                        text = formatHour(entry.hour),
                                        style = TextStyle(
                                            fontSize = 7.sp,
                                            color = ColorProvider(subTextColor),
                                        ),
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = GlanceModifier.height(6.dp))

                // 3. Wave bar chart
                if (waveHeights.isNotEmpty()) {
                    Row(
                        modifier = GlanceModifier.fillMaxWidth(),
                        verticalAlignment = Alignment.Vertical.Bottom,
                    ) {
                        val maxBars = minOf(waveHeights.size, 18)
                        val maxWave = waveHeights.take(maxBars).maxOfOrNull { it.wave } ?: 1.0
                        val maxBarHeight = 30

                        for (i in 0 until maxBars) {
                            val entry = waveHeights[i]
                            val normalized = if (maxWave > 0) entry.wave / maxWave else 0.0
                            val barHeight = maxOf((normalized * maxBarHeight).toInt(), 2)
                            Column(
                                modifier = GlanceModifier.defaultWeight(),
                                horizontalAlignment = Alignment.Horizontal.CenterHorizontally,
                            ) {
                                Box(
                                    modifier = GlanceModifier
                                        .width(4.dp)
                                        .height(barHeight.dp)
                                        .background(ColorProvider(conditionColorWithAlpha(score, 0.6f)))
                                        .cornerRadius(2.dp),
                                ) {}
                            }
                        }
                    }
                }

                Spacer(modifier = GlanceModifier.height(6.dp))

                // 4. Best window card
                if (bestLabel.isNotEmpty() && bestStart.isNotEmpty()) {
                    Box(
                        modifier = GlanceModifier
                            .fillMaxWidth()
                            .padding(horizontal = 8.dp, vertical = 6.dp)
                            .background(ColorProvider(android.graphics.Color.argb(25, 61, 145, 137)))
                            .cornerRadius(8.dp),
                    ) {
                        Row(
                            modifier = GlanceModifier.fillMaxWidth(),
                            verticalAlignment = Alignment.Vertical.CenterVertically,
                        ) {
                            Text(
                                text = "Best: ${formatBestWindow(bestStart, bestEnd)}",
                                style = TextStyle(
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = ColorProvider(teal),
                                ),
                            )
                            Spacer(modifier = GlanceModifier.defaultWeight())
                            Text(
                                text = "$bestLabel · $bestScore",
                                style = TextStyle(
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = ColorProvider(teal),
                                ),
                            )
                        }
                    }
                }

                Spacer(modifier = GlanceModifier.height(4.dp))

                // 5. Upcoming windows
                for ((idx, window) in upcomingWindows.take(3).withIndex()) {
                    Row(
                        modifier = GlanceModifier.fillMaxWidth().padding(vertical = 2.dp),
                        verticalAlignment = Alignment.Vertical.CenterVertically,
                    ) {
                        Text(
                            text = window.dayLabel,
                            style = TextStyle(
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Medium,
                                color = ColorProvider(subTextColor),
                            ),
                            modifier = GlanceModifier.width(52.dp),
                        )
                        Text(
                            text = window.timeRange,
                            style = TextStyle(
                                fontSize = 10.sp,
                                color = ColorProvider(lightColor),
                            ),
                        )
                        Spacer(modifier = GlanceModifier.defaultWeight())
                        if (window.wave != null) {
                            Text(
                                text = "${String.format("%.1f", window.wave)}ft",
                                style = TextStyle(
                                    fontSize = 10.sp,
                                    color = ColorProvider(subTextColor),
                                ),
                            )
                            Spacer(modifier = GlanceModifier.width(4.dp))
                        }
                        Text(
                            text = window.label,
                            style = TextStyle(
                                fontSize = 9.sp,
                                fontWeight = FontWeight.Medium,
                                color = ColorProvider(conditionColor(window.score)),
                            ),
                        )
                    }
                }
            }
        }
    }

    private fun formatHour(hour: Int): String = when {
        hour == 0 -> "12a"
        hour < 12 -> "${hour}a"
        hour == 12 -> "12p"
        else -> "${hour - 12}p"
    }

    private fun formatBestWindow(start: String, end: String): String {
        return try {
            val startHour = start.substring(11, 13).toIntOrNull() ?: return ""
            val endHour = end.substring(11, 13).toIntOrNull() ?: return ""
            "${formatHour(startHour)}-${formatHour(endHour)}"
        } catch (_: Exception) {
            ""
        }
    }
}

// Data classes for new JSON fields

data class WaveEntry(val hour: Int, val wave: Double)

fun parseWaveHeights(json: String): List<WaveEntry> {
    return try {
        val arr = JSONArray(json)
        (0 until arr.length()).map { i ->
            val obj = arr.getJSONObject(i)
            WaveEntry(
                hour = obj.getInt("h"),
                wave = if (obj.isNull("w")) 0.0 else obj.getDouble("w"),
            )
        }
    } catch (_: Exception) {
        emptyList()
    }
}

data class WindowEntry(
    val startTime: String,
    val endTime: String,
    val score: Int,
    val label: String,
    val wave: Double?,
) {
    val timeRange: String
        get() {
            return try {
                val sh = startTime.substring(11, 13).toIntOrNull() ?: return ""
                val eh = endTime.substring(11, 13).toIntOrNull() ?: return ""
                "${fmtHr(sh)}-${fmtHr(eh)}"
            } catch (_: Exception) { "" }
        }

    val dayLabel: String
        get() {
            return try {
                val datePart = startTime.substring(0, 10)
                val today = java.time.LocalDate.now().toString()
                val tomorrow = java.time.LocalDate.now().plusDays(1).toString()
                when (datePart) {
                    today -> "Today"
                    tomorrow -> "Tmrw"
                    else -> {
                        val d = java.time.LocalDate.parse(datePart)
                        d.dayOfWeek.name.take(3).lowercase()
                            .replaceFirstChar { it.uppercase() }
                    }
                }
            } catch (_: Exception) { "" }
        }

    private fun fmtHr(h: Int): String = when {
        h == 0 -> "12a"
        h < 12 -> "${h}a"
        h == 12 -> "12p"
        else -> "${h - 12}p"
    }
}

fun parseUpcomingWindows(json: String): List<WindowEntry> {
    return try {
        val arr = JSONArray(json)
        (0 until arr.length()).map { i ->
            val obj = arr.getJSONObject(i)
            WindowEntry(
                startTime = obj.getString("start"),
                endTime = obj.getString("end"),
                score = obj.getInt("score"),
                label = obj.getString("label"),
                wave = if (obj.isNull("wave")) null else obj.getDouble("wave"),
            )
        }
    } catch (_: Exception) {
        emptyList()
    }
}
