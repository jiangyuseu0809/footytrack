package com.footballtracker.server.routes

import com.footballtracker.server.config.AvatarConfig
import com.footballtracker.server.service.FeedbackService
import io.ktor.http.*
import io.ktor.http.content.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import java.io.File
import java.util.*

@Serializable
data class SubmitFeedbackRequest(
    val content: String,
    val imageUrls: List<String>? = null
)

fun Route.feedbackRoutes(feedbackService: FeedbackService, avatarConfig: AvatarConfig) {
    route("/feedback") {
        post {
            val uid = UUID.fromString(call.jwtUid())
            val req = call.receive<SubmitFeedbackRequest>()

            if (req.content.isBlank()) {
                call.respond(HttpStatusCode.BadRequest, mapOf("error" to "反馈内容不能为空"))
                return@post
            }

            val imageUrlsStr = req.imageUrls?.joinToString(",")
            feedbackService.submitFeedback(uid, req.content, imageUrlsStr)
            call.respond(mapOf("success" to true))
        }

        post("/upload") {
            val uid = UUID.fromString(call.jwtUid())
            val multipart = call.receiveMultipart()
            var fileUrl = ""

            multipart.forEachPart { part ->
                if (part is PartData.FileItem) {
                    val bytes = part.streamProvider().readBytes()
                    if (bytes.size.toLong() > avatarConfig.maxBytes) {
                        call.respond(HttpStatusCode.PayloadTooLarge, mapOf("error" to "图片过大"))
                        part.dispose()
                        return@forEachPart
                    }

                    val feedbackDir = File(avatarConfig.baseDir, "feedback")
                    if (!feedbackDir.exists()) feedbackDir.mkdirs()

                    val filename = "fb-${uid}-${System.currentTimeMillis()}.jpg"
                    val target = File(feedbackDir, filename)
                    target.writeBytes(bytes)

                    fileUrl = "${avatarConfig.publicBaseUrl.trimEnd('/')}/feedback/$filename"
                }
                part.dispose()
            }

            call.respond(mapOf("url" to fileUrl))
        }
    }
}
