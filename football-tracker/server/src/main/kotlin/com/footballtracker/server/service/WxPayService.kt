package com.footballtracker.server.service

import com.footballtracker.server.config.WxPayConfig
import com.footballtracker.server.db.tables.DonationTable
import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import kotlinx.serialization.json.*
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.transactions.transaction
import org.jetbrains.exposed.sql.update
import java.security.KeyFactory
import java.security.Signature
import java.util.*
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

class WxPayService(private val config: WxPayConfig) {

    private val client = HttpClient(CIO)
    private val notifyUrl = "https://footytrack.cn/api/donation/notify"

    /**
     * Create a JSAPI order via WeChat Pay v3 API (public-key auth mode).
     * Returns the prepay_id.
     */
    suspend fun createOrder(openId: String, amountCents: Int, description: String, outTradeNo: String): String {
        val body = buildJsonObject {
            put("appid", config.mpAppId)
            put("mchid", config.mchId)
            put("description", description)
            put("out_trade_no", outTradeNo)
            put("notify_url", notifyUrl)
            putJsonObject("amount") {
                put("total", amountCents)
                put("currency", "CNY")
            }
            putJsonObject("payer") {
                put("openid", openId)
            }
        }.toString()

        val method = "POST"
        val urlPath = "/v3/pay/transactions/jsapi"
        val timestamp = (System.currentTimeMillis() / 1000).toString()
        val nonceStr = UUID.randomUUID().toString().replace("-", "")

        val signature = sign("$method\n$urlPath\n$timestamp\n$nonceStr\n$body\n")

        val authorization = """WECHATPAY2-SHA256-RSA2048 mchid="${config.mchId}",serial_no="${config.pubKeyId}",nonce_str="$nonceStr",timestamp="$timestamp",signature="$signature""""

        val resp = client.post("https://api.mch.weixin.qq.com$urlPath") {
            header(HttpHeaders.Authorization, authorization)
            header(HttpHeaders.ContentType, ContentType.Application.Json.toString())
            header("Wechatpay-Serial", config.pubKeyId)
            setBody(body)
        }

        val respText = resp.bodyAsText()
        if (resp.status != HttpStatusCode.OK && resp.status != HttpStatusCode.NoContent) {
            throw IllegalStateException("微信下单失败: $respText")
        }

        val respJson = Json.parseToJsonElement(respText).jsonObject
        return respJson["prepay_id"]?.jsonPrimitive?.content
            ?: throw IllegalStateException("微信返回无 prepay_id: $respText")
    }

    /**
     * Build the parameters the mini-program needs for wx.requestPayment().
     */
    fun buildJsapiParams(prepayId: String): Map<String, String> {
        val timestamp = (System.currentTimeMillis() / 1000).toString()
        val nonceStr = UUID.randomUUID().toString().replace("-", "")
        val pkg = "prepay_id=$prepayId"

        val paySign = sign("${config.mpAppId}\n$timestamp\n$nonceStr\n$pkg\n")

        return mapOf(
            "timeStamp" to timestamp,
            "nonceStr" to nonceStr,
            "package" to pkg,
            "signType" to "RSA",
            "paySign" to paySign
        )
    }

    /**
     * Decrypt the notification body from WeChat Pay callback.
     * Returns the parsed JSON resource object.
     */
    fun decryptNotification(bodyText: String): JsonObject {
        val bodyJson = Json.parseToJsonElement(bodyText).jsonObject
        val resource = bodyJson["resource"]?.jsonObject
            ?: throw IllegalArgumentException("missing resource in notification")

        val nonce = resource["nonce"]?.jsonPrimitive?.content
            ?: throw IllegalArgumentException("missing nonce")
        val ciphertext = resource["ciphertext"]?.jsonPrimitive?.content
            ?: throw IllegalArgumentException("missing ciphertext")
        val associatedData = resource["associated_data"]?.jsonPrimitive?.content ?: ""

        val key = config.apiV3Key.toByteArray(Charsets.UTF_8)
        val secretKey = SecretKeySpec(key, "AES")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val spec = GCMParameterSpec(128, nonce.toByteArray(Charsets.UTF_8))
        cipher.init(Cipher.DECRYPT_MODE, secretKey, spec)
        cipher.updateAAD(associatedData.toByteArray(Charsets.UTF_8))

        val decrypted = cipher.doFinal(Base64.getDecoder().decode(ciphertext))
        return Json.parseToJsonElement(String(decrypted, Charsets.UTF_8)).jsonObject
    }

    /**
     * Create a donation record in the database.
     */
    fun createDonationRecord(userUid: UUID, amountCents: Int, outTradeNo: String) {
        transaction {
            DonationTable.insert {
                it[DonationTable.id] = UUID.randomUUID()
                it[DonationTable.userUid] = userUid
                it[DonationTable.amountCents] = amountCents
                it[DonationTable.outTradeNo] = outTradeNo
                it[DonationTable.status] = "pending"
                it[DonationTable.createdAt] = System.currentTimeMillis()
            }
        }
    }

    /**
     * Mark a donation as paid.
     */
    fun markPaid(outTradeNo: String, transactionId: String?) {
        transaction {
            DonationTable.update({ DonationTable.outTradeNo eq outTradeNo }) {
                it[DonationTable.status] = "paid"
                it[DonationTable.paidAt] = System.currentTimeMillis()
                if (transactionId != null) {
                    it[DonationTable.transactionId] = transactionId
                }
            }
        }
    }

    /**
     * RSA-SHA256 sign with the merchant's private key (PEM loaded from config).
     */
    private fun sign(message: String): String {
        val pemContent = config.pubKeyPem
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replace("\\s".toRegex(), "")

        val keyBytes = Base64.getDecoder().decode(pemContent)
        val keySpec = java.security.spec.PKCS8EncodedKeySpec(keyBytes)
        val privateKey = KeyFactory.getInstance("RSA").generatePrivate(keySpec)

        val sig = Signature.getInstance("SHA256withRSA")
        sig.initSign(privateKey)
        sig.update(message.toByteArray(Charsets.UTF_8))
        return Base64.getEncoder().encodeToString(sig.sign())
    }
}
