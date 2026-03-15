package com.footballtracker.android.wxapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.footballtracker.android.FootballTrackerApp
import com.footballtracker.android.auth.WeChatAuthHelper
import com.tencent.mm.opensdk.modelbase.BaseReq
import com.tencent.mm.opensdk.modelbase.BaseResp
import com.tencent.mm.opensdk.modelmsg.SendAuth
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler
import com.tencent.mm.opensdk.openapi.WXAPIFactory

/**
 * WeChat OAuth callback Activity.
 *
 * WeChat SDK requires this class to be at the exact path:
 *   {packageName}.wxapi.WXEntryActivity
 */
class WXEntryActivity : Activity(), IWXAPIEventHandler {

    private val api by lazy {
        WXAPIFactory.createWXAPI(this, WeChatAuthHelper.WECHAT_APP_ID, false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        api.handleIntent(intent, this)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        api.handleIntent(intent, this)
    }

    override fun onReq(req: BaseReq?) {
        // Not used for login flow
    }

    override fun onResp(resp: BaseResp?) {
        if (resp is SendAuth.Resp) {
            when (resp.errCode) {
                BaseResp.ErrCode.ERR_OK -> {
                    val code = resp.code
                    if (code != null) {
                        val helper = (application as FootballTrackerApp).appContainer.weChatAuthHelper
                        helper.onAuthCodeReceived(code)
                    }
                }
                BaseResp.ErrCode.ERR_USER_CANCEL -> { /* User cancelled */ }
                else -> { /* Auth failed */ }
            }
        }
        finish()
    }
}
