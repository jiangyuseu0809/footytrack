package com.footballtracker.android.data.model

data class UserProfile(
    val uid: String,
    val nickname: String,
    val weightKg: Double = 70.0,
    val age: Int = 25,
    val authProvider: String = "phone",  // "phone" | "wechat"
    val phone: String? = null,
    val wechatOpenId: String? = null,
    val createdAt: Long = System.currentTimeMillis()
)
