package com.footballtracker.server.service

import com.footballtracker.server.config.TencentConfig
import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import kotlinx.serialization.json.*
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.*
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

class TencentSmsService(private val config: TencentConfig) {

    private val client = HttpClient(CIO)
    private val host = "sms.tencentcloudapi.com"
    private val service = "sms"

    suspend fun sendSmsCode(phone: String, code: String): Boolean {
        val phoneNumber = if (phone.startsWith("+")) phone else "+86$phone"
        val timestamp = (System.currentTimeMillis() / 1000).toString()
        val date = SimpleDateFormat("yyyy-MM-dd").apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date())

        val payload = buildJsonObject {
            put("SmsSdkAppId", config.sdkAppId)
            put("SignName", config.signName)
            put("TemplateId", config.templateId)
            putJsonArray("TemplateParamSet") { add(code) }
            putJsonArray("PhoneNumberSet") { add(phoneNumber) }
        }.toString()

        val authorization = buildAuthorization(timestamp, date, payload)

        val response = client.post("https://$host") {
            header("Host", host)
            header("Content-Type", "application/json; charset=utf-8")
            header("X-TC-Action", "SendSms")
            header("X-TC-Version", "2021-01-11")
            header("X-TC-Timestamp", timestamp)
            header("X-TC-Region", "ap-guangzhou")
            header("Authorization", authorization)
            setBody(payload)
        }

        val body = response.bodyAsText()
        val json = Json.parseToJsonElement(body).jsonObject
        val responseObj = json["Response"]?.jsonObject
        val sendStatusSet = responseObj?.get("SendStatusSet")?.jsonArray
        val statusCode = sendStatusSet?.firstOrNull()?.jsonObject?.get("Code")?.jsonPrimitive?.content

        return statusCode == "Ok"
    }

    private fun buildAuthorization(timestamp: String, date: String, payload: String): String {
        val httpRequestMethod = "POST"
        val canonicalUri = "/"
        val canonicalQueryString = ""
        val canonicalHeaders = "content-type:application/json; charset=utf-8\nhost:$host\n"
        val signedHeaders = "content-type;host"
        val hashedPayload = sha256Hex(payload)

        val canonicalRequest = "$httpRequestMethod\n$canonicalUri\n$canonicalQueryString\n$canonicalHeaders\n$signedHeaders\n$hashedPayload"
        val credentialScope = "$date/$service/tc3_request"
        val stringToSign = "TC3-HMAC-SHA256\n$timestamp\n$credentialScope\n${sha256Hex(canonicalRequest)}"

        val secretDate = hmacSha256("TC3${config.secretKey}".toByteArray(), date)
        val secretService = hmacSha256(secretDate, service)
        val secretSigning = hmacSha256(secretService, "tc3_request")
        val signature = hmacSha256(secretSigning, stringToSign).joinToString("") { "%02x".format(it) }

        return "TC3-HMAC-SHA256 " +
                "Credential=${config.secretId}/$credentialScope, " +
                "SignedHeaders=$signedHeaders, " +
                "Signature=$signature"
    }

    private fun sha256Hex(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(input.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }

    private fun hmacSha256(key: ByteArray, data: String): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return mac.doFinal(data.toByteArray())
    }
}
