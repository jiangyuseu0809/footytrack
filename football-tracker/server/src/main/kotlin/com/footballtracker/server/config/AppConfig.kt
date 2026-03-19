package com.footballtracker.server.config

import io.ktor.server.application.*

data class AppConfig(
    val database: DatabaseConfig,
    val jwt: JwtConfig,
    val tencent: TencentConfig,
    val wechat: WeChatConfig,
    val avatar: AvatarConfig
)

data class DatabaseConfig(
    val url: String,
    val user: String,
    val password: String
)

data class JwtConfig(
    val secret: String,
    val issuer: String,
    val audience: String,
    val expirationDays: Long
)

data class TencentConfig(
    val secretId: String,
    val secretKey: String,
    val sdkAppId: String,
    val signName: String,
    val templateId: String
)

data class WeChatConfig(
    val appId: String,
    val appSecret: String
)

data class AvatarConfig(
    val baseDir: String,
    val publicBaseUrl: String,
    val maxBytes: Long
)

fun Application.loadConfig(): AppConfig {
    val config = environment.config
    fun env(key: String, yamlPath: String): String =
        System.getenv(key) ?: config.property(yamlPath).getString()

    return AppConfig(
        database = DatabaseConfig(
            url = env("APP_DATABASE_URL", "app.database.url"),
            user = env("APP_DATABASE_USER", "app.database.user"),
            password = env("APP_DATABASE_PASSWORD", "app.database.password")
        ),
        jwt = JwtConfig(
            secret = env("APP_JWT_SECRET", "app.jwt.secret"),
            issuer = env("APP_JWT_ISSUER", "app.jwt.issuer"),
            audience = env("APP_JWT_AUDIENCE", "app.jwt.audience"),
            expirationDays = env("APP_JWT_EXPIRATION_DAYS", "app.jwt.expirationDays").toLong()
        ),
        tencent = TencentConfig(
            secretId = env("APP_TENCENT_SECRET_ID", "app.tencent.secretId"),
            secretKey = env("APP_TENCENT_SECRET_KEY", "app.tencent.secretKey"),
            sdkAppId = env("APP_TENCENT_SDK_APP_ID", "app.tencent.sdkAppId"),
            signName = env("APP_TENCENT_SIGN_NAME", "app.tencent.signName"),
            templateId = env("APP_TENCENT_TEMPLATE_ID", "app.tencent.templateId")
        ),
        wechat = WeChatConfig(
            appId = env("APP_WECHAT_APP_ID", "app.wechat.appId"),
            appSecret = env("APP_WECHAT_APP_SECRET", "app.wechat.appSecret")
        ),
        avatar = AvatarConfig(
            baseDir = env("APP_AVATAR_BASE_DIR", "app.avatar.baseDir"),
            publicBaseUrl = env("APP_AVATAR_PUBLIC_BASE_URL", "app.avatar.publicBaseUrl"),
            maxBytes = env("APP_AVATAR_MAX_BYTES", "app.avatar.maxBytes").toLong()
        )
    )
}
