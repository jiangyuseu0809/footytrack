package com.footballtracker.server.service

import com.footballtracker.server.config.WeChatConfig
import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import kotlinx.serialization.json.*

data class WeChatUserInfo(
    val openId: String,
    val nickname: String
)

class WeChatService(private val config: WeChatConfig) {

    private val client = HttpClient(CIO)

    suspend fun exchangeCodeForUser(code: String): WeChatUserInfo {
        // Step 1: Exchange code for access_token + openid
        val tokenResponse = client.get(
            "https://api.weixin.qq.com/sns/oauth2/access_token" +
                    "?appid=${config.appId}" +
                    "&secret=${config.appSecret}" +
                    "&code=$code" +
                    "&grant_type=authorization_code"
        )

        val tokenJson = Json.parseToJsonElement(tokenResponse.bodyAsText()).jsonObject
        if (tokenJson.containsKey("errcode")) {
            val errMsg = tokenJson["errmsg"]?.jsonPrimitive?.content ?: "unknown"
            throw IllegalArgumentException("微信授权失败: $errMsg")
        }

        val accessToken = tokenJson["access_token"]!!.jsonPrimitive.content
        val openId = tokenJson["openid"]!!.jsonPrimitive.content

        // Step 2: Fetch user info
        val userInfoResponse = client.get(
            "https://api.weixin.qq.com/sns/userinfo" +
                    "?access_token=$accessToken" +
                    "&openid=$openId" +
                    "&lang=zh_CN"
        )

        val userJson = Json.parseToJsonElement(userInfoResponse.bodyAsText()).jsonObject
        val nickname = userJson["nickname"]?.jsonPrimitive?.content ?: "微信用户"

        return WeChatUserInfo(openId = openId, nickname = nickname)
    }

    /**
     * Mini-program login: exchange js_code for openid via jscode2session
     */
    suspend fun exchangeCodeForMpOpenId(code: String): String {
        val resp = client.get(
            "https://api.weixin.qq.com/sns/jscode2session" +
                    "?appid=${config.mpAppId}" +
                    "&secret=${config.mpAppSecret}" +
                    "&js_code=$code" +
                    "&grant_type=authorization_code"
        )

        val json = Json.parseToJsonElement(resp.bodyAsText()).jsonObject
        val errcode = json["errcode"]?.jsonPrimitive?.int ?: 0
        if (errcode != 0) {
            val errMsg = json["errmsg"]?.jsonPrimitive?.content ?: "unknown"
            throw IllegalArgumentException("小程序登录失败: $errMsg")
        }

        return json["openid"]!!.jsonPrimitive.content
    }
}
