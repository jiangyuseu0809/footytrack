package com.footballtracker.android.data.repository

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import com.footballtracker.android.data.model.UserProfile
import com.footballtracker.android.network.ApiClient
import com.footballtracker.android.network.UpdateProfileRequest
import kotlinx.coroutines.flow.first

private val Context.userDataStore: DataStore<Preferences> by preferencesDataStore(name = "user_profile")

class UserRepository(private val context: Context) {

    private val dataStore = context.userDataStore

    // DataStore keys
    private object Keys {
        val UID = stringPreferencesKey("uid")
        val NICKNAME = stringPreferencesKey("nickname")
        val WEIGHT = doublePreferencesKey("weight_kg")
        val AGE = intPreferencesKey("age")
        val AUTH_PROVIDER = stringPreferencesKey("auth_provider")
        val PHONE = stringPreferencesKey("phone")
        val WECHAT_OPEN_ID = stringPreferencesKey("wechat_open_id")
        val CREATED_AT = longPreferencesKey("created_at")
    }

    /**
     * Save user profile to server and local DataStore cache.
     */
    suspend fun saveProfile(profile: UserProfile) {
        // Cache locally first so data is never lost
        cacheProfile(profile)

        // Then update on server (best-effort)
        try {
            ApiClient.api.updateProfile(
                UpdateProfileRequest(
                    nickname = profile.nickname,
                    weightKg = profile.weightKg,
                    age = profile.age
                )
            )
        } catch (_: Exception) {
            // Server update failed — local cache still has the data
        }
    }

    /**
     * Get user profile. Tries local cache first, falls back to server API.
     */
    suspend fun getProfile(uid: String): UserProfile? {
        // Try local cache first
        val cached = getCachedProfile()
        if (cached != null && cached.uid == uid) return cached

        // Fetch from server
        return try {
            val response = ApiClient.api.getProfile()
            val profile = UserProfile(
                uid = response.uid,
                nickname = response.nickname,
                weightKg = response.weightKg,
                age = response.age,
                authProvider = response.authProvider,
                phone = response.phone,
                wechatOpenId = response.wechatOpenId,
                createdAt = response.createdAt
            )
            cacheProfile(profile)
            profile
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Update specific profile fields.
     */
    suspend fun updateProfile(uid: String, nickname: String? = null, weightKg: Double? = null, age: Int? = null) {
        if (nickname == null && weightKg == null && age == null) return

        ApiClient.api.updateProfile(UpdateProfileRequest(nickname = nickname, weightKg = weightKg, age = age))

        // Update local cache
        val cached = getCachedProfile()
        if (cached != null && cached.uid == uid) {
            cacheProfile(
                cached.copy(
                    nickname = nickname ?: cached.nickname,
                    weightKg = weightKg ?: cached.weightKg,
                    age = age ?: cached.age
                )
            )
        }
    }

    /**
     * Clear local cache on logout.
     */
    suspend fun clearCache() {
        dataStore.edit { it.clear() }
    }

    private suspend fun cacheProfile(profile: UserProfile) {
        dataStore.edit { prefs ->
            prefs[Keys.UID] = profile.uid
            prefs[Keys.NICKNAME] = profile.nickname
            prefs[Keys.WEIGHT] = profile.weightKg
            prefs[Keys.AGE] = profile.age
            prefs[Keys.AUTH_PROVIDER] = profile.authProvider
            profile.phone?.let { prefs[Keys.PHONE] = it } ?: prefs.remove(Keys.PHONE)
            profile.wechatOpenId?.let { prefs[Keys.WECHAT_OPEN_ID] = it } ?: prefs.remove(Keys.WECHAT_OPEN_ID)
            prefs[Keys.CREATED_AT] = profile.createdAt
        }
    }

    private suspend fun getCachedProfile(): UserProfile? {
        val prefs = dataStore.data.first()
        val uid = prefs[Keys.UID] ?: return null
        return UserProfile(
            uid = uid,
            nickname = prefs[Keys.NICKNAME] ?: "",
            weightKg = prefs[Keys.WEIGHT] ?: 70.0,
            age = prefs[Keys.AGE] ?: 25,
            authProvider = prefs[Keys.AUTH_PROVIDER] ?: "phone",
            phone = prefs[Keys.PHONE],
            wechatOpenId = prefs[Keys.WECHAT_OPEN_ID],
            createdAt = prefs[Keys.CREATED_AT] ?: 0L
        )
    }
}
