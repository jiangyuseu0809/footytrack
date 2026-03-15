package com.footballtracker.android.network

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.runBlocking

private val Context.tokenDataStore: DataStore<Preferences> by preferencesDataStore(name = "auth_token")

class TokenStore(private val context: Context) {

    private object Keys {
        val TOKEN = stringPreferencesKey("jwt_token")
        val UID = stringPreferencesKey("uid")
    }

    // In-memory cache for synchronous access by OkHttp interceptor
    @Volatile
    private var cachedToken: String? = null

    @Volatile
    private var cachedUid: String? = null

    fun init() {
        // Load from DataStore into memory on startup
        runBlocking {
            val prefs = context.tokenDataStore.data.first()
            cachedToken = prefs[Keys.TOKEN]
            cachedUid = prefs[Keys.UID]
        }
    }

    suspend fun saveToken(token: String, uid: String) {
        cachedToken = token
        cachedUid = uid
        context.tokenDataStore.edit { prefs ->
            prefs[Keys.TOKEN] = token
            prefs[Keys.UID] = uid
        }
    }

    suspend fun clear() {
        cachedToken = null
        cachedUid = null
        context.tokenDataStore.edit { it.clear() }
    }

    fun getToken(): String? = cachedToken

    fun getUid(): String? = cachedUid

    fun isLoggedIn(): Boolean = cachedToken != null
}
