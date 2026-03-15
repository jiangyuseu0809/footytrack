import SwiftUI

// MARK: - Color Palette (matches Android Theme.kt)

enum AppColors {
    static let darkBg       = Color(hex: 0x0D1117)
    static let cardBg       = Color(hex: 0x161B22)
    static let cardBgLight  = Color(hex: 0x1C2333)
    static let dividerColor = Color(hex: 0x30363D)

    static let neonBlue     = Color(hex: 0x00E676)  // Primary green
    static let neonPurple   = Color(hex: 0x00BFA5)  // Secondary teal

    static let textPrimary   = Color.white
    static let textSecondary = Color(hex: 0x8B949E)

    static let heartRed      = Color(hex: 0xFF4757)
    static let heartRedLight = Color(hex: 0xFF6B81)
    static let calorieOrange = Color(hex: 0xFFA502)
    static let calorieOrangeD = Color(hex: 0xFF6348)
    static let speedGreen    = Color(hex: 0x2ED573)
    static let speedGreenL   = Color(hex: 0x7BED9F)

    static let slackGreen  = Color(hex: 0x2ED573)
    static let slackYellow = Color(hex: 0xFFA502)
    static let slackRed    = Color(hex: 0xFF4757)

    // Gradient helpers
    static let neonGradient     = LinearGradient(colors: [neonBlue, neonPurple], startPoint: .leading, endPoint: .trailing)
    static let neonGradientV    = LinearGradient(colors: [neonBlue, neonPurple], startPoint: .top, endPoint: .bottom)
    static let heartGradient    = LinearGradient(colors: [heartRed, heartRedLight], startPoint: .leading, endPoint: .trailing)
    static let calorieGradient  = LinearGradient(colors: [calorieOrange, calorieOrangeD], startPoint: .leading, endPoint: .trailing)
    static let speedGradient    = LinearGradient(colors: [speedGreen, speedGreenL], startPoint: .leading, endPoint: .trailing)
    static let distanceGradient = LinearGradient(colors: [neonBlue, Color(hex: 0x69F0AE)], startPoint: .leading, endPoint: .trailing)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
