package com.footballtracker.server.auth

import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap

class BindCodeStore {

    private data class CodeEntry(val uid: String, val expiresAt: Long)

    private val store = ConcurrentHashMap<String, CodeEntry>()
    private val ttlMs = 5 * 60 * 1000L  // 5 minutes

    private val cleanupJob = CoroutineScope(Dispatchers.Default + SupervisorJob()).launch {
        while (isActive) {
            delay(60_000)
            val now = System.currentTimeMillis()
            store.entries.removeIf { it.value.expiresAt < now }
        }
    }

    fun generateCode(): String {
        return (100000..999999).random().toString()
    }

    fun storeCode(code: String, uid: String) {
        store[code] = CodeEntry(uid, System.currentTimeMillis() + ttlMs)
    }

    /** Returns the user UID if code is valid, null otherwise. Auto-deletes on success. */
    fun verifyCode(code: String): String? {
        val entry = store[code] ?: return null
        if (entry.expiresAt < System.currentTimeMillis()) {
            store.remove(code)
            return null
        }
        store.remove(code)
        return entry.uid
    }
}
