package com.footballtracker.server.service

import com.footballtracker.server.config.OpenAiConfig
import com.footballtracker.server.db.tables.SessionSummariesTable
import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.transactions.transaction

@Serializable
data class SessionSummaryRequest(
    val sessionId: String,
    val durationMinutes: Int,
    val distanceKm: Double,
    val maxSpeedKmh: Double,
    val sprintCount: Int,
    val caloriesBurned: Double,
    val avgHeartRate: Int,
    val goals: Int,
    val assists: Int,
    val coveragePercent: Double
)

class SessionSummaryService(private val openAiConfig: OpenAiConfig) {
    private val client = HttpClient(CIO)
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun getOrCreateSummary(req: SessionSummaryRequest): String {
        val cached = transaction {
            SessionSummariesTable.selectAll()
                .where { SessionSummariesTable.sessionId eq req.sessionId }
                .firstOrNull()
                ?.get(SessionSummariesTable.summary)
        }
        if (cached != null) return cached

        val summary = generateSummary(req)
        transaction {
            SessionSummariesTable.insert {
                it[sessionId] = req.sessionId
                it[SessionSummariesTable.summary] = summary
                it[createdAt] = System.currentTimeMillis()
            }
        }
        return summary
    }

    private suspend fun generateSummary(req: SessionSummaryRequest): String {
        val prompt = """
你是一个专业的足球数据分析师。根据以下单场比赛的运动数据，生成一段简洁的比赛总结分析。

本场数据：
- 时长：${req.durationMinutes} 分钟
- 跑动距离：${"%.2f".format(req.distanceKm)} km
- 最高速度：${"%.1f".format(req.maxSpeedKmh)} km/h
- 冲刺次数：${req.sprintCount} 次
- 消耗热量：${"%.0f".format(req.caloriesBurned)} kcal
- 平均心率：${req.avgHeartRate} bpm
- 进球：${req.goals}，助攻：${req.assists}
- 场地覆盖率：${"%.1f".format(req.coveragePercent)}%

请生成150字以内的中文比赛总结，包含本场表现亮点、运动强度评价和简短建议。直接返回纯文本，不要 markdown 格式。
""".trim()

        val apiUrl = "${openAiConfig.endpoint}/openai/deployments/${openAiConfig.deploymentName}/chat/completions?api-version=2025-04-01-preview"

        val requestBody = buildJsonObject {
            putJsonArray("messages") {
                addJsonObject {
                    put("role", "user")
                    put("content", prompt)
                }
            }
            put("temperature", 0.7)
            put("max_completion_tokens", 400)
        }

        val response = client.post(apiUrl) {
            contentType(ContentType.Application.Json)
            header("api-key", openAiConfig.apiKey)
            setBody(requestBody.toString())
        }

        val responseText = response.bodyAsText()
        val responseJson = json.parseToJsonElement(responseText).jsonObject

        return responseJson["choices"]
            ?.jsonArray?.firstOrNull()
            ?.jsonObject?.get("message")
            ?.jsonObject?.get("content")
            ?.jsonPrimitive?.content
            ?.trim()
            ?: throw RuntimeException("Failed to parse Azure OpenAI response")
    }
}
