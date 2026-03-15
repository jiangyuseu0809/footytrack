package com.footballtracker.android.auth

import com.footballtracker.android.network.ApiClient
import com.footballtracker.android.network.LoginRequest
import com.footballtracker.android.network.RegisterRequest
import com.footballtracker.android.network.SmsSendRequest
import com.footballtracker.android.network.SmsVerifyRequest
import com.footballtracker.android.network.TokenStore
import com.footballtracker.android.network.WeChatAuthRequest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class AuthState(
    val uid: String,
    val phone: String? = null,
    val username: String? = null
)

class AuthRepository(private val tokenStore: TokenStore) {

    private val _currentUser = MutableStateFlow<AuthState?>(null)
    val currentUser: StateFlow<AuthState?> = _currentUser.asStateFlow()

    init {
        // Restore auth state from persisted token
        if (tokenStore.isLoggedIn()) {
            _currentUser.value = AuthState(uid = tokenStore.getUid()!!)
        }
    }

    suspend fun sendVerificationCode(phoneNumber: String): Result<Unit> {
        return try {
            ApiClient.api.sendSmsCode(SmsSendRequest(phone = phoneNumber))
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun verifyCode(phone: String, code: String): Result<AuthState> {
        return try {
            val response = ApiClient.api.verifySmsCode(SmsVerifyRequest(phone = phone, code = code))
            tokenStore.saveToken(response.token, response.uid)
            val state = AuthState(uid = response.uid, phone = phone)
            _currentUser.value = state
            Result.success(state)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun signInWithWeChat(code: String): Result<AuthState> {
        return try {
            val response = ApiClient.api.wechatAuth(WeChatAuthRequest(code = code))
            tokenStore.saveToken(response.token, response.uid)
            val state = AuthState(uid = response.uid)
            _currentUser.value = state
            Result.success(state)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    fun isNewUser(result: Result<*>): Boolean {
        // Check from the last auth response
        return lastAuthIsNewUser
    }

    @Volatile
    private var lastAuthIsNewUser = false

    suspend fun verifyCodeCheckNew(phone: String, code: String): Pair<Result<AuthState>, Boolean> {
        return try {
            val response = ApiClient.api.verifySmsCode(SmsVerifyRequest(phone = phone, code = code))
            tokenStore.saveToken(response.token, response.uid)
            val state = AuthState(uid = response.uid, phone = phone)
            _currentUser.value = state
            Pair(Result.success(state), response.isNewUser)
        } catch (e: Exception) {
            Pair(Result.failure(e), false)
        }
    }

    suspend fun signInWithWeChatCheckNew(code: String): Pair<Result<AuthState>, Boolean> {
        return try {
            val response = ApiClient.api.wechatAuth(WeChatAuthRequest(code = code))
            tokenStore.saveToken(response.token, response.uid)
            val state = AuthState(uid = response.uid)
            _currentUser.value = state
            Pair(Result.success(state), response.isNewUser)
        } catch (e: Exception) {
            Pair(Result.failure(e), false)
        }
    }

    suspend fun register(username: String, password: String): Pair<Result<AuthState>, Boolean> {
        return try {
            val response = ApiClient.api.register(RegisterRequest(username = username, password = password))
            tokenStore.saveToken(response.token, response.uid)
            val state = AuthState(uid = response.uid, username = username)
            _currentUser.value = state
            Pair(Result.success(state), response.isNewUser)
        } catch (e: Exception) {
            Pair(Result.failure(e), false)
        }
    }

    suspend fun login(username: String, password: String): Pair<Result<AuthState>, Boolean> {
        return try {
            val response = ApiClient.api.login(LoginRequest(username = username, password = password))
            tokenStore.saveToken(response.token, response.uid)
            val state = AuthState(uid = response.uid, username = username)
            _currentUser.value = state
            Pair(Result.success(state), response.isNewUser)
        } catch (e: Exception) {
            Pair(Result.failure(e), false)
        }
    }

    suspend fun signOut() {
        tokenStore.clear()
        _currentUser.value = null
    }

    fun isLoggedIn(): Boolean = tokenStore.isLoggedIn()
}
