import SwiftUI

struct OnboardingView: View {
    @ObservedObject var authManager: AuthManager
    @State private var nickname = ""
    @State private var weightText = "70"
    @State private var ageText = "25"
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 40)

                    VStack(spacing: 8) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 50))
                            .foregroundStyle(AppColors.neonGradient)

                        Text("完善你的资料")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)

                        Text("帮助我们更准确地计算数据")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    VStack(spacing: 16) {
                        inputField(icon: "person.fill", placeholder: "昵称", text: $nickname)
                        inputField(icon: "scalemass.fill", placeholder: "体重 (kg)", text: $weightText, keyboard: .decimalPad)
                        inputField(icon: "calendar", placeholder: "年龄", text: $ageText, keyboard: .numberPad)
                    }
                    .padding(.horizontal, 24)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.heartRed)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        submit()
                    } label: {
                        Group {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text("完成")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.neonGradient)
                        .cornerRadius(12)
                    }
                    .disabled(nickname.isEmpty || isSubmitting)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }

    private func submit() {
        let weight = Double(weightText) ?? 70.0
        let age = Int(ageText) ?? 25
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let _ = try await ApiClient.shared.updateProfile(
                    UpdateProfileRequest(nickname: nickname, weightKg: weight, age: age)
                )
                // Profile updated, auth flow will dismiss automatically since isLoggedIn is already true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    @ViewBuilder
    private func inputField(icon: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppColors.textSecondary)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(AppColors.textSecondary))
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(keyboard)
                .autocapitalization(.none)
        }
        .padding()
        .background(AppColors.cardBg)
        .cornerRadius(12)
    }
}
