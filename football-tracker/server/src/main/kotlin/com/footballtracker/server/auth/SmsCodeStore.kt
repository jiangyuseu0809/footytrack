package com.footballtracker.server.auth

import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap

class SmsCodeStore {

    private data class CodeEntry(val code: String, val expiresAt: Long)

    private val store = ConcurrentHashMap<String, CodeEntry>()
    private val ttlMs = 5 * 60 * 1000L  // 5 minutes

    private val cleanupJob = CoroutineScope(Dispatchers.Default + SupervisorJob()).launch {
        while (isActive) {
            delay(60_000)  // Clean up every minute
            val now = System.currentTimeMillis()
            store.entries.removeIf { it.value.expiresAt < now }
        }
    }

    fun storeCode(phone: String, code: String) {
        store[phone] = CodeEntry(code, System.currentTimeMillis() + ttlMs)
    }

    fun verifyCode(phone: String, code: String): Boolean {
        val entry = store[phone] ?: return false
        if (entry.expiresAt < System.currentTimeMillis()) {
            store.remove(phone)
            return false
        }
        if (entry.code == code) {
            store.remove(phone)
            return true
        }
        return false
    }

    fun generateCode(): String {
        return (100000..999999).random().toString()
    }
}
