import SwiftUI

struct LoginView: View {
    @ObservedObject var authManager: AuthManager
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

                        Text("野球记")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)

                        Text("记录你的每一场球")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
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
                        Task { await authManager.login(username: username, password: password) }
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
            RegisterView(authManager: authManager)
        }
        .navigationBarHidden(true)
    }
}
