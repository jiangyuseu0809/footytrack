package com.footballtracker.android

import android.app.Application
import com.footballtracker.android.auth.AuthRepository
import com.footballtracker.android.auth.WeChatAuthHelper
import com.footballtracker.android.data.repository.CloudSessionSync
import com.footballtracker.android.data.repository.SessionRepo
import com.footballtracker.android.data.repository.UserRepository
import com.footballtracker.android.network.ApiClient
import com.footballtracker.android.network.TokenStore
import com.footballtracker.android.sync.WatchController

class FootballTrackerApp : Application() {

    lateinit var appContainer: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        appContainer = AppContainer(this)
    }
}

class AppContainer(private val context: android.content.Context) {

    val tokenStore: TokenStore by lazy {
        TokenStore(context).also {
            it.init()
            ApiClient.init(it)
        }
    }

    val sessionRepo: SessionRepo by lazy { SessionRepo(context) }

    val authRepository: AuthRepository by lazy { AuthRepository(tokenStore) }

    val userRepository: UserRepository by lazy { UserRepository(context) }

    val cloudSync: CloudSessionSync by lazy {
        CloudSessionSync(sessionRepo, authRepository)
    }

    val weChatAuthHelper: WeChatAuthHelper by lazy { WeChatAuthHelper(context) }

    val watchController: WatchController by lazy { WatchController(context) }
}
