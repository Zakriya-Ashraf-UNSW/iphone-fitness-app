import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum Theme {
    // True OLED & Dark Surfaces for iPhone 16 Pro Max
    public static let background = Color(red: 0.0, green: 0.0, blue: 0.0)
    public static let surface = Color(red: 9/255, green: 9/255, blue: 11/255)
    public static let surfaceElevated = Color(red: 24/255, green: 24/255, blue: 27/255)
    public static let surfaceCard = Color(red: 20/255, green: 20/255, blue: 24/255)
    public static let surfaceCardSecondary = Color(red: 27/255, green: 27/255, blue: 31/255)
    public static let border = Color(red: 39/255, green: 39/255, blue: 42/255)
    public static let borderHighlight = Color(red: 63/255, green: 63/255, blue: 70/255)

    // Vibrant Signal Accents
    public static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    public static let emeraldGlow = Color(red: 5/255, green: 150/255, blue: 105/255)
    public static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
    public static let amberGlow = Color(red: 217/255, green: 119/255, blue: 6/255)
    public static let sky = Color(red: 56/255, green: 189/255, blue: 248/255)
    public static let cyan = Color(red: 6/255, green: 182/255, blue: 212/255)
    public static let crimson = Color(red: 239/255, green: 68/255, blue: 68/255)
    public static let rose = Color(red: 244/255, green: 63/255, blue: 94/255)
    public static let purple = Color(red: 168/255, green: 85/255, blue: 247/255)

    // Typography
    public static let textPrimary = Color(red: 248/255, green: 250/255, blue: 252/255)
    public static let textSecondary = Color(red: 148/255, green: 163/255, blue: 184/255)
    public static let textMuted = Color(red: 100/255, green: 116/255, blue: 139/255)

    // Sensory Haptics
    #if canImport(UIKit)
    public static func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    public static func hapticNotification(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    public static func hapticTick() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.7)
    }

    public static func hapticSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    public static func hapticWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    #else
    public static func hapticImpact(_ style: Int = 0) {}
    public static func hapticNotification(_ type: Int = 0) {}
    public static func hapticTick() {}
    public static func hapticSuccess() {}
    public static func hapticWarning() {}
    #endif
}

#if canImport(UIKit)
public extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#else
public extension View {
    func hideKeyboard() {}
}
#endif
