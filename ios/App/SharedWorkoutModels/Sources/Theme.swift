import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum Theme {
    public static let background = Color(red: 0.0, green: 0.0, blue: 0.0)
    public static let surface = Color(red: 9/255, green: 9/255, blue: 11/255)
    public static let surfaceElevated = Color(red: 24/255, green: 24/255, blue: 27/255)
    public static let surfaceCard = Color(red: 31/255, green: 31/255, blue: 35/255)
    public static let border = Color(red: 39/255, green: 39/255, blue: 42/255)
    public static let borderHighlight = Color(red: 63/255, green: 63/255, blue: 70/255)

    // Signal Colors
    public static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    public static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
    public static let sky = Color(red: 56/255, green: 189/255, blue: 248/255)
    public static let crimson = Color(red: 239/255, green: 68/255, blue: 68/255)
    public static let purple = Color(red: 168/255, green: 85/255, blue: 247/255)

    // Typography Colors
    public static let textPrimary = Color(red: 248/255, green: 250/255, blue: 252/255)
    public static let textSecondary = Color(red: 148/255, green: 163/255, blue: 184/255)
    public static let textMuted = Color(red: 100/255, green: 116/255, blue: 139/255)

    // Haptics
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
    #else
    public static func hapticImpact(_ style: Int = 0) {}
    public static func hapticNotification(_ type: Int = 0) {}
    #endif
}
