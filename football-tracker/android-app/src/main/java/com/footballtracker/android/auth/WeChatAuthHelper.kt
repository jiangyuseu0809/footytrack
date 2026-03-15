package com.footballtracker.android.auth

import android.content.Context
import com.tencent.mm.opensdk.modelmsg.SendAuth
import com.tencent.mm.opensdk.openapi.IWXAPI
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Helper for WeChat SDK login flow.
 *
 * Before use, set your WeChat AppID:
 *   WeChatAuthHelper.WECHAT_APP_ID = "wx_your_app_id"
 */
class WeChatAuthHelper(context: Context) {

    companion object {
        var WECHAT_APP_ID = "YOUR_WECHAT_APP_ID"
    }

    private val api: IWXAPI = WXAPIFactory.createWXAPI(context, WECHAT_APP_ID, true)

    // Flow to receive the WeChat auth code from WXEntryActivity
    private val _authCode = MutableStateFlow<String?>(null)
    val authCode: StateFlow<String?> = _authCode.asStateFlow()

    init {
        api.registerApp(WECHAT_APP_ID)
    }

    /**
     * Check if WeChat is installed on the device.
     */
    fun isWeChatInstalled(): Boolean = api.isWXAppInstalled

    /**
     * Launch the WeChat login screen.
     */
    fun login() {
        val req = SendAuth.Req()
        req.scope = "snsapi_userinfo"
        req.state = "football_tracker_login"
        api.sendReq(req)
    }

    /**
     * Called by WXEntryActivity when WeChat returns the auth code.
     */
    fun onAuthCodeReceived(code: String) {
        _authCode.value = code
    }

    /**
     * Clear the auth code after it's been consumed.
     */
    fun clearAuthCode() {
        _authCode.value = null
    }
}
