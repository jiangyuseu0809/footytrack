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

@Serializable
data class SessionSummaryResult(
    val summary: String,
    val highlights: List<String>,
    val improvements: List<String>
)

class SessionSummaryService(private val openAiConfig: OpenAiConfig) {
    private val client = HttpClient(CIO)
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun getOrCreateSummary(req: SessionSummaryRequest): SessionSummaryResult {
        val cached = transaction {
            SessionSummariesTable.selectAll()
                .where { SessionSummariesTable.sessionId eq req.sessionId }
                .firstOrNull()
                ?.get(SessionSummariesTable.summary)
        }
        if (cached != null) {
            return try {
                json.decodeFromString<SessionSummaryResult>(cached)
            } catch (e: Exception) {
                // Legacy plain-text cache — delete and regenerate
                transaction {
                    SessionSummariesTable.deleteWhere { SessionSummariesTable.sessionId eq req.sessionId }
                }
                generateAndCache(req)
            }
        }
        return generateAndCache(req)
    }

    private suspend fun generateAndCache(req: SessionSummaryRequest): SessionSummaryResult {
        val result = generateSummary(req)
        val serialized = json.encodeToString(SessionSummaryResult.serializer(), result)
        transaction {
            SessionSummariesTable.insert {
                it[sessionId] = req.sessionId
                it[summary] = serialized
                it[createdAt] = System.currentTimeMillis()
            }
        }
        return result
    }

    private suspend fun generateSummary(req: SessionSummaryRequest): SessionSummaryResult {
        val prompt = """
你是一个专业的足球数据分析师。根据以下单场比赛的运动数据，生成结构化的比赛分析。

本场数据：
- 时长：${req.durationMinutes} 分钟
- 跑动距离：${"%.2f".format(req.distanceKm)} km
- 最高速度：${"%.1f".format(req.maxSpeedKmh)} km/h
- 冲刺次数：${req.sprintCount} 次
- 消耗热量：${"%.0f".format(req.caloriesBurned)} kcal
- 平均心率：${req.avgHeartRate} bpm
- 进球：${req.goals}，助攻：${req.assists}
- 场地覆盖率：${"%.1f".format(req.coveragePercent)}%

请返回 JSON 格式（不要 markdown）：
{
  "summary": "一到两句话的整体总结",
  "highlights": ["亮点1", "亮点2", "亮点3"],
  "improvements": ["改进建议1", "改进建议2"]
}
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

        val content = responseJson["choices"]
            ?.jsonArray?.firstOrNull()
            ?.jsonObject?.get("message")
            ?.jsonObject?.get("content")
            ?.jsonPrimitive?.content
            ?.trim()
            ?.removePrefix("```json")
            ?.removePrefix("```")
            ?.removeSuffix("```")
            ?.trim()
            ?: throw RuntimeException("Failed to parse Azure OpenAI response")

        return json.decodeFromString<SessionSummaryResult>(content)
    }
}

