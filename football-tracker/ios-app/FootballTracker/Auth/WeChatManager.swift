import Foundation

/// Manages WeChat SDK registration, login flow, and callback handling.
/// Acts as WXApiDelegate to receive auth responses from WeChat.
@MainActor
final class WeChatManager: NSObject, ObservableObject {

    static let shared = WeChatManager()

    static let appId = "wx3d3b45f95f14dce4"
    static let universalLink = "https://footytrack.cn/app/"

    /// Called when WeChat auth completes (success or failure).
    var onAuthCodeReceived: ((Result<String, WeChatAuthError>) -> Void)?

    @Published var isWeChatInstalled: Bool = false

    private override init() {
        super.init()
    }

    /// Register with WeChat SDK. Call once at app launch.
    func register() {
        WXApi.registerApp(Self.appId, universalLink: Self.universalLink)
        WXApi.startLog(by: .normal) { _ in }
        checkInstallation()
    }

    func checkInstallation() {
        isWeChatInstalled = WXApi.isWXAppInstalled()
    }

    /// Initiate WeChat OAuth login.
    func login() {
        let req = SendAuthReq()
        req.scope = "snsapi_userinfo"
        req.state = UUID().uuidString
        WXApi.send(req)
    }

    /// Handle URL callback from WeChat (URL Scheme).
    func handleOpenURL(_ url: URL) -> Bool {
        print("[WeChat] handleOpenURL called: \(url)")
        return WXApi.handleOpen(url, delegate: self)
    }

    /// Handle Universal Link callback from WeChat.
    func handleOpenUniversalLink(_ userActivity: NSUserActivity) -> Bool {
        WXApi.handleOpenUniversalLink(userActivity, delegate: self)
    }
}

// MARK: - WXApiDelegate

extension WeChatManager: WXApiDelegate {

    nonisolated func onReq(_ req: BaseReq) {
        // Incoming requests from WeChat — not used
    }

    nonisolated func onResp(_ resp: BaseResp) {
        print("[WeChat] onResp called, errCode: \(resp.errCode), type: \(type(of: resp))")
        Task { @MainActor in
            guard let authResp = resp as? SendAuthResp else {
                print("[WeChat] resp is not SendAuthResp, ignoring")
                return
            }

            print("[WeChat] auth errCode: \(authResp.errCode), code: \(authResp.code ?? "nil")")
            switch Int(authResp.errCode) {
            case 0:
                if let code = authResp.code, !code.isEmpty {
                    onAuthCodeReceived?(.success(code))
                } else {
                    onAuthCodeReceived?(.failure(.noCode))
                }
            case -2:
                onAuthCodeReceived?(.failure(.cancelled))
            case -4:
                onAuthCodeReceived?(.failure(.denied))
            default:
                onAuthCodeReceived?(.failure(.unknown(Int(authResp.errCode))))
            }
        }
    }
}

// MARK: - Error

enum WeChatAuthError: LocalizedError {
    case notInstalled
    case cancelled
    case denied
    case noCode
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .notInstalled: return "未安装微信"
        case .cancelled: return "已取消授权"
        case .denied: return "授权被拒绝"
        case .noCode: return "未获取到授权码"
        case .unknown(let code): return "微信授权失败(\(code))"
        }
    }
}
