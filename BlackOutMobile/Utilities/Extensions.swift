import SwiftUI

// MARK: - Date Formatting

extension Date {
    /// e.g. "Feb 12, 2026 at 9:30 PM"
    var mediumFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// e.g. "9:30 PM"
    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// e.g. "Feb 12"
    var shortDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }

    /// Relative: "2 hours ago", "Just now"
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - TimeInterval Formatting

extension TimeInterval {
    /// Format as "HH:MM:SS" countdown
    var countdownFormatted: String {
        guard self > 0 else { return "00:00:00" }
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Format as human-readable "X hours, Y minutes"
    var humanReadable: String {
        guard self > 0 else { return "Expired" }
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else if hours > 0 {
            return "\(hours)h remaining"
        } else if minutes > 0 {
            return "\(minutes)m remaining"
        } else {
            return "Less than a minute"
        }
    }
}

// MARK: - Color Theme

extension Color {
    static let cardBlack = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let surfaceDark = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let surfaceMedium = Color(red: 0.18, green: 0.18, blue: 0.20)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.6)
    static let accentPurple = Color(red: 0.50, green: 0.30, blue: 1.0)
    static let accentGlow = Color(red: 0.55, green: 0.35, blue: 1.0)
    static let dangerRed = Color(red: 1.0, green: 0.30, blue: 0.30)
    static let successGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
    static let warningAmber = Color(red: 1.0, green: 0.75, blue: 0.20)
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.surfaceDark)
            .cornerRadius(16)
    }
}

struct GlowingCardStyle: ViewModifier {
    var glowColor: Color = .accentPurple

    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.surfaceDark)
            .cornerRadius(16)
            .shadow(color: glowColor.opacity(0.3), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func glowingCardStyle(color: Color = .accentPurple) -> some View {
        modifier(GlowingCardStyle(glowColor: color))
    }
}

// MARK: - Primary Button Style

struct BlackoutButtonStyle: ButtonStyle {
    var color: Color = .accentPurple

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color)
                    .shadow(color: color.opacity(0.4), radius: configuration.isPressed ? 2 : 6)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Animation.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.accentPurple)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentPurple, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Animation.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
