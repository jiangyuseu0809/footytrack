package com.footballtracker.server.service

import com.footballtracker.server.db.tables.FeedbackTable
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.transactions.transaction
import java.util.*

class FeedbackService {

    fun submitFeedback(userUid: UUID, content: String, imageUrls: String?) {
        transaction {
            FeedbackTable.insert {
                it[FeedbackTable.id] = UUID.randomUUID()
                it[FeedbackTable.userUid] = userUid
                it[FeedbackTable.content] = content
                it[FeedbackTable.imageUrls] = imageUrls
                it[FeedbackTable.createdAt] = System.currentTimeMillis()
            }
        }
    }
}
