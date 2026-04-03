import SwiftUI

struct WatchBindView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var success = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("绑定账号")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("在小程序中生成绑定码")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                TextField("6位绑定码", text: $code)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .frame(height: 44)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                if success {
                    Text("绑定成功!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Button(action: handleBind) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("绑定")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(code.count != 6 || isLoading)
                }
            }
            .padding(8)
        }
    }

    private func handleBind() {
        guard code.count == 6 else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await bindWithCode(code)
                WatchApiClient.shared.token = result.token
                WatchApiClient.shared.uid = result.uid

                await MainActor.run {
                    PhoneSync.shared.isAuthenticated = true
                    success = true
                }

                // Flush queued sessions
                let synced = await WatchSessionQueue.shared.flushQueue()
                if synced > 0 {
                    print("[WatchBind] Flushed \(synced) queued sessions after bind")
                }

                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func bindWithCode(_ code: String) async throws -> BindResponse {
        guard let url = URL(string: "https://footytrack.cn/api/auth/bind/verify") else {
            throw WatchApiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(BindRequest(code: code))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchApiError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw BindError.invalidCode
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw WatchApiError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(BindResponse.self, from: data)
    }
}

private struct BindRequest: Encodable {
    let code: String
}

private struct BindResponse: Decodable {
    let token: String
    let uid: String
}

private enum BindError: LocalizedError {
    case invalidCode

    var errorDescription: String? {
        switch self {
        case .invalidCode: return "绑定码无效或已过期"
        }
    }
}
