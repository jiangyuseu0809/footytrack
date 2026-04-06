import SwiftUI
import WatchKit

struct WatchBindView: View {
    @State private var code: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var success = false

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("绑定账号")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Text("在小程序「我的」中生成绑定码")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                // Code display
                HStack(spacing: 4) {
                    ForEach(0..<6, id: \.self) { i in
                        let digit = i < code.count ? String(code[code.index(code.startIndex, offsetBy: i)]) : ""
                        Text(digit)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(digit.isEmpty ? 0.08 : 0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(i == code.count ? Color.green : Color.clear, lineWidth: 1.5)
                            )
                    }
                }
                .padding(.vertical, 4)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                if success {
                    Text("绑定成功!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.green)
                }

                // Number pad
                if !success {
                    numPad
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
    }

    // MARK: - Number Pad

    private var numPad: some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(1...3, id: \.self) { col in
                        let num = row * 3 + col
                        numButton(String(num))
                    }
                }
            }
            HStack(spacing: 4) {
                // Bind button (replaces empty space)
                Button(action: handleBind) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 32)
                    } else {
                        Text("确定")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(code.count == 6 ? .white : .gray)
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                }
                .disabled(code.count != 6 || isLoading)
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(code.count == 6 ? Color.green : Color.white.opacity(0.08))
                )

                numButton("0")

                // Delete button
                Button(action: { if !code.isEmpty { code.removeLast() } }) {
                    Image(systemName: "delete.backward")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                )
            }
        }
    }

    private func numButton(_ num: String) -> some View {
        Button(action: {
            if code.count < 6 {
                code += num
                if code.count == 6 {
                    handleBind()
                }
            }
        }) {
            Text(num)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.12))
        )
    }

    // MARK: - Bind

    private func handleBind() {
        guard code.count == 6, !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await bindWithCode(code)
                WatchApiClient.shared.token = result.token
                WatchApiClient.shared.uid = result.uid

                await MainActor.run {
                    success = true
                    isLoading = false
                }

                try? await Task.sleep(nanoseconds: 800_000_000)
                await MainActor.run {
                    PhoneSync.shared.isAuthenticated = true
                }

                Task.detached(priority: .background) {
                    let synced = await WatchSessionQueue.shared.flushQueue()
                    if synced > 0 {
                        print("[WatchBind] Flushed \(synced) queued sessions after bind")
                    }
                }
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
        request.timeoutInterval = 15
        request.httpBody = try JSONEncoder().encode(BindRequest(
            code: code,
            brand: "Apple",
            model: WKInterfaceDevice.current().name
        ))

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
    let brand: String
    let model: String
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
