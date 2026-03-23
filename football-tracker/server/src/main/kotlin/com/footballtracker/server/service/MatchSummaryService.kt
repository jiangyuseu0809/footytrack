package com.footballtracker.server.service

import com.footballtracker.server.config.OpenAiConfig
import com.footballtracker.server.db.tables.MatchSummariesTable
import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import kotlinx.serialization.json.*
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.transactions.transaction
import java.util.*

class MatchSummaryService(
    private val openAiConfig: OpenAiConfig,
    private val sessionService: SessionService,
    private val matchService: MatchService
) {
    private val client = HttpClient(CIO)
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun getOrCreateSummary(matchId: UUID): String {
        // Check cache
        val cached = transaction {
            MatchSummariesTable.selectAll()
                .where { MatchSummariesTable.matchId eq matchId }
                .firstOrNull()
                ?.get(MatchSummariesTable.summary)
        }
        if (cached != null) return cached

        // Generate and cache
        val summary = generateSummary(matchId)
        transaction {
            MatchSummariesTable.insert {
                it[MatchSummariesTable.matchId] = matchId
                it[MatchSummariesTable.summary] = summary
                it[MatchSummariesTable.createdAt] = System.currentTimeMillis()
            }
        }
        return summary
    }

    private suspend fun generateSummary(matchId: UUID): String {
        val match = matchService.getMatchById(matchId)
            ?: throw RuntimeException("比赛不存在")

        val registrations = matchService.getMatchRegistrations(matchId)
        if (registrations.isEmpty()) {
            return "暂无参赛球员数据，无法生成比赛总结。"
        }

        // Collect per-player stats
        val playerStats = registrations.map { reg ->
            val sessions = sessionService.getSessionsByOwner(reg.userUid)
            val totalDistance = sessions.mapNotNull { it.totalDistanceMeters }.sum()
            val totalCalories = sessions.mapNotNull { it.caloriesBurned }.sum()
            val maxSpeed = sessions.mapNotNull { it.maxSpeedKmh }.maxOrNull() ?: 0.0
            val avgSpeed = sessions.mapNotNull { it.avgSpeedKmh }.let { speeds ->
                if (speeds.isEmpty()) 0.0 else speeds.sum() / speeds.size
            }
            val totalSprints = sessions.mapNotNull { it.sprintCount }.sum()

            val nickname = reg.nickname.ifEmpty { "球员" }
            val colorLabel = if (reg.groupColor.isNotEmpty()) "${reg.groupColor}队" else "未分组"
            "$nickname ($colorLabel)：总距离 ${"%.1f".format(totalDistance / 1000.0)}km，热量 ${"%.0f".format(totalCalories)}kcal，最高速度 ${"%.1f".format(maxSpeed)}km/h，场均速度 ${"%.1f".format(avgSpeed)}km/h，冲刺${totalSprints}次"
        }

        val matchDateStr = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm", java.util.Locale.CHINA).apply {
            timeZone = java.util.TimeZone.getTimeZone("Asia/Shanghai")
        }.format(java.util.Date(match.matchDate))

        val groupColorsText = match.groupColors.split(",").joinToString("、") { it.trim() }

        val prompt = """
你是一个足球比赛分析师。根据以下比赛信息和球员数据，生成一段比赛总结。

比赛：${match.title}
时间：$matchDateStr
地点：${match.location}
分组：$groupColorsText

各球员数据：
${playerStats.joinToString("\n")}

请生成一段200字以内的中文比赛总结，包含：
1. 整体比赛评价
2. 各队表现对比
3. 最佳球员表现点评
4. 一句话总结

直接返回纯文本，不要 markdown 格式。
""".trim()

        val apiUrl = "${openAiConfig.endpoint}/openai/deployments/${openAiConfig.deploymentName}/chat/completions?api-version=2024-02-15-preview"

        val requestBody = buildJsonObject {
            putJsonArray("messages") {
                addJsonObject {
                    put("role", "user")
                    put("content", prompt)
                }
            }
            put("temperature", 0.7)
            put("max_tokens", 500)
        }

        val response = client.post(apiUrl) {
            contentType(ContentType.Application.Json)
            header("api-key", openAiConfig.apiKey)
            setBody(requestBody.toString())
        }

        val responseText = response.bodyAsText()
        val responseJson = json.parseToJsonElement(responseText).jsonObject

        val content = responseJson["choices"]
            ?.jsonArray?.firstOrNull()
            ?.jsonObject?.get("message")
            ?.jsonObject?.get("content")
            ?.jsonPrimitive?.content
            ?: throw RuntimeException("Failed to parse Azure OpenAI response")

        return content.trim()
    }
}
