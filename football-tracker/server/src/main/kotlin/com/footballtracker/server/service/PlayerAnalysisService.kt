package com.footballtracker.server.service

import com.footballtracker.server.config.OpenAiConfig
import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*
import java.util.*

@Serializable
data class PlayerAnalysisResult(
    val type: String,
    val description: String,
    val strengths: List<String>,
    val advice: String
)

class PlayerAnalysisService(
    private val openAiConfig: OpenAiConfig,
    private val sessionService: SessionService
) {
    private val client = HttpClient(CIO)
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun analyzePlayerType(ownerUid: UUID): PlayerAnalysisResult {
        val sessions = sessionService.getSessionsByOwner(ownerUid)
        if (sessions.isEmpty()) {
            return PlayerAnalysisResult(
                type = "未知",
                description = "暂无比赛数据，无法分析球员类型。",
                strengths = emptyList(),
                advice = "完成至少一场比赛后再来查看分析结果。"
            )
        }

        val totalSessions = sessions.size
        val totalDistanceKm = sessions.mapNotNull { it.totalDistanceMeters }.sum() / 1000.0
        val avgDistanceKm = totalDistanceKm / totalSessions
        val maxSpeedKmh = sessions.mapNotNull { it.maxSpeedKmh }.maxOrNull() ?: 0.0
        val avgSprints = sessions.mapNotNull { it.sprintCount }.let { counts ->
            if (counts.isEmpty()) 0.0 else counts.sum().toDouble() / counts.size
        }
        val avgHeartRate = sessions.mapNotNull { it.avgHeartRate }.let { rates ->
            if (rates.isEmpty()) 0 else rates.sum() / rates.size
        }
        val avgCalories = sessions.mapNotNull { it.caloriesBurned }.let { cals ->
            if (cals.isEmpty()) 0.0 else cals.sum() / cals.size
        }
        val avgCoverage = sessions.mapNotNull { it.coveragePercent }.let { covs ->
            if (covs.isEmpty()) 0.0 else covs.sum() / covs.size
        }

        val prompt = """
你是一个足球数据分析师。根据以下球员的生涯统计数据，分析该球员的类型。

球员数据：
- 总比赛场次: $totalSessions
- 总跑动距离: ${"%.1f".format(totalDistanceKm)} km
- 场均跑动距离: ${"%.1f".format(avgDistanceKm)} km
- 最高速度: ${"%.1f".format(maxSpeedKmh)} km/h
- 场均冲刺次数: ${"%.0f".format(avgSprints)}
- 场均心率: $avgHeartRate bpm
- 场均卡路里: ${"%.0f".format(avgCalories)}
- 场均覆盖率: ${"%.1f".format(avgCoverage)}%

请返回 JSON 格式（不要 markdown）：
{
  "type": "球员类型名称（如：中场发动机/冲刺先锋/组织核心/防守铁闸/全能战士）",
  "description": "一句话描述该球员风格",
  "strengths": ["优势1", "优势2", "优势3"],
  "advice": "一句话提升建议"
}
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

        val cleanContent = content.trim()
            .removePrefix("```json")
            .removePrefix("```")
            .removeSuffix("```")
            .trim()

        return json.decodeFromString<PlayerAnalysisResult>(cleanContent)
    }
}
