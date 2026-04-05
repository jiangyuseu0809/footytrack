package com.footballtracker.server.routes

import com.footballtracker.server.db.tables.UsersTable
import com.footballtracker.server.service.WxPayService
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.jsonPrimitive
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.transactions.transaction
import java.util.*

@Serializable
data class CreateDonationRequest(val amount: Int) // amount in cents

fun Route.donationRoutes(wxPayService: WxPayService) {
    route("/donation") {
        post("/create") {
            val uid = UUID.fromString(call.jwtUid())
            val req = call.receive<CreateDonationRequest>()

            if (req.amount !in listOf(100, 200, 500, 1000, 2000, 5000)) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "无效的打赏金额"))
                return@post
            }

            val openId = transaction {
                UsersTable.selectAll().where { UsersTable.uid eq uid }
                    .map { it[UsersTable.wechatOpenId] }
                    .firstOrNull()
            }

            if (openId.isNullOrBlank()) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "未绑定微信，无法支付"))
                return@post
            }

            val outTradeNo = "FT${System.currentTimeMillis()}${(1000..9999).random()}"
            val description = "FootyTrack 打赏"

            wxPayService.createDonationRecord(uid, req.amount, outTradeNo)

            val prepayId = wxPayService.createOrder(openId, req.amount, description, outTradeNo)
            val params = wxPayService.buildJsapiParams(prepayId)

            call.respond(params)
        }
    }
}

fun Route.donationNotifyRoute(wxPayService: WxPayService) {
    route("/donation") {
        post("/notify") {
            try {
                val bodyText = call.receiveText()
                val resource = wxPayService.decryptNotification(bodyText)

                val outTradeNo = resource["out_trade_no"]?.jsonPrimitive?.content
                val tradeState = resource["trade_state"]?.jsonPrimitive?.content
                val transactionId = resource["transaction_id"]?.jsonPrimitive?.content

                if (outTradeNo != null && tradeState == "SUCCESS") {
                    wxPayService.markPaid(outTradeNo, transactionId)
                }

                call.respond(mapOf("code" to "SUCCESS", "message" to "OK"))
            } catch (e: Exception) {
                call.application.log.error("Donation notify error", e)
                call.respond(HttpStatusCode.InternalServerError, mapOf("code" to "FAIL", "message" to e.message))
            }
        }
    }
}
