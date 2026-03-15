import SwiftUI

struct RegisterView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var validationError: String?
    @State private var showOnboarding = false

    private var isValid: Bool {
        username.count >= 3 && username.count <= 20 &&
        password.count >= 6 &&
        password == confirmPassword
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundStyle(AppColors.neonGradient)

                        Text("创建账号")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }

                    // Fields
                    VStack(spacing: 16) {
                        fieldRow(icon: "person.fill", placeholder: "用户名 (3-20位)", text: $username)
                        fieldRow(icon: "lock.fill", placeholder: "密码 (至少6位)", text: $password, isSecure: true)
                        fieldRow(icon: "lock.fill", placeholder: "确认密码", text: $confirmPassword, isSecure: true)
                    }
                    .padding(.horizontal, 24)

                    // Validation / Error
                    if let error = validationError ?? authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.heartRed)
                            .padding(.horizontal, 24)
                    }

                    // Register Button
                    Button {
                        register()
                    } label: {
                        Group {
                            if authManager.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("注册")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.neonGradient)
                        .cornerRadius(12)
                    }
                    .disabled(!isValid || authManager.isLoading)
                    .padding(.horizontal, 24)

                    // Back to login
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Text("已有账号？")
                                .foregroundColor(AppColors.textSecondary)
                            Text("登录")
                                .foregroundColor(AppColors.neonBlue)
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }

                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showOnboarding) {
            OnboardingView(authManager: authManager)
        }
    }

    private func register() {
        validationError = nil
        if username.count < 3 || username.count > 20 {
            validationError = "用户名须3-20个字符"; return
        }
        if password.count < 6 {
            validationError = "密码至少6位"; return
        }
        if password != confirmPassword {
            validationError = "两次输入的密码不一致"; return
        }

        Task {
            let isNew = await authManager.register(username: username, password: password)
            if authManager.isLoggedIn {
                showOnboarding = isNew
            }
        }
    }

    @ViewBuilder
    private func fieldRow(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppColors.textSecondary)
            if isSecure {
                SecureField("", text: text, prompt: Text(placeholder).foregroundColor(AppColors.textSecondary))
                    .foregroundColor(AppColors.textPrimary)
                    .autocapitalization(.none)
            } else {
                TextField("", text: text, prompt: Text(placeholder).foregroundColor(AppColors.textSecondary))
                    .foregroundColor(AppColors.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
        .padding()
        .background(AppColors.cardBg)
        .cornerRadius(12)
    }
}
