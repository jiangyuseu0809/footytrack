import SwiftUI

struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    var store: SessionStore? = nil
    @ObservedObject private var wechatManager = WeChatManager.shared
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showRegister = false

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)

                    // Logo + Title
                    VStack(spacing: 12) {
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(AppColors.neonGradient)

                        Text("FootyTrack")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)

                        Text("记录你的每一场球")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    // WeChat Login Button (primary)
                    if wechatManager.isWeChatInstalled {
                        Button {
                            authManager.loginWithWeChat(store: store)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)

                                Text("微信登录")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: 0x07C160))
                            .cornerRadius(12)
                        }
                        .disabled(authManager.isLoading)
                        .padding(.horizontal, 24)

                        // Divider
                        HStack {
                            Rectangle().fill(AppColors.dividerColor).frame(height: 0.5)
                            Text("或")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 12)
                            Rectangle().fill(AppColors.dividerColor).frame(height: 0.5)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Input Fields
                    VStack(spacing: 16) {
                        // Username
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(AppColors.textSecondary)
                            TextField("", text: $username, prompt: Text("用户名").foregroundColor(AppColors.textSecondary))
                                .foregroundColor(AppColors.textPrimary)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding()
                        .background(AppColors.cardBg)
                        .cornerRadius(12)

                        // Password
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(AppColors.textSecondary)
                            Group {
                                if showPassword {
                                    TextField("", text: $password, prompt: Text("密码").foregroundColor(AppColors.textSecondary))
                                } else {
                                    SecureField("", text: $password, prompt: Text("密码").foregroundColor(AppColors.textSecondary))
                                }
                            }
                            .foregroundColor(AppColors.textPrimary)
                            .autocapitalization(.none)

                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding()
                        .background(AppColors.cardBg)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)

                    // Error
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.heartRed)
                            .padding(.horizontal, 24)
                    }

                    // Login Button
                    Button {
                        Task { await authManager.login(username: username, password: password, store: store) }
                    } label: {
                        Group {
                            if authManager.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("登录")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.neonGradient)
                        .cornerRadius(12)
                    }
                    .disabled(username.isEmpty || password.isEmpty || authManager.isLoading)
                    .padding(.horizontal, 24)

                    // Register link
                    Button {
                        showRegister = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("没有账号？")
                                .foregroundColor(AppColors.textSecondary)
                            Text("注册")
                                .foregroundColor(AppColors.neonBlue)
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }

                    Spacer()
                }
            }
        }
        .navigationDestination(isPresented: $showRegister) {
            RegisterView(authManager: authManager, store: store)
        }
        .navigationBarHidden(true)
        .onAppear {
            wechatManager.checkInstallation()
        }
    }
}
