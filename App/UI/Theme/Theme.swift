import SwiftUI

/// Tokens of docs/GUI.md §2 ("High Noon"). Colours are sRGB.
enum Theme {
    static let sun = Color(hex: 0xF6B642)
    static let sunCore = Color(hex: 0xFFE2A0)
    static let ember = Color(hex: 0xE2572B)
    static let plum = Color(hex: 0x5B1E3A)
    static let night = Color(hex: 0x1A0F14)
    static let cream = Color(hex: 0xFFF1D6)
    static let danger = Color(hex: 0xD8382E)
    static let hudWhite = Color.white

    /// Player colours of PLAN.md §1B.8, by `colorIndex` 0–9.
    static let playerColors: [Color] = [
        Color(hex: 0x4E79A7), Color(hex: 0xF28E2B), Color(hex: 0xE15759), Color(hex: 0x76B7B2),
        Color(hex: 0x59A14F), Color(hex: 0xEDC948), Color(hex: 0xB07AA1), Color(hex: 0xFF9DA7),
        Color(hex: 0x9C755F), Color(hex: 0xBAB0AC),
    ]

    static let alfaName = "AlfaSlabOne-Regular"
    static let barlowSemiBoldName = "BarlowCondensed-SemiBold"
    static let barlowMediumName = "BarlowCondensed-Medium"
    static let fontNames = [alfaName, barlowSemiBoldName, barlowMediumName]

    static let wordmarkSize: CGFloat = 44
    static let wordmark = Font.custom(alfaName, fixedSize: wordmarkSize)
    static let title = Font.custom(alfaName, size: 28, relativeTo: .title)
    static let button = Font.custom(barlowSemiBoldName, size: 20, relativeTo: .headline)
    static let body = Font.custom(barlowMediumName, size: 18, relativeTo: .body)
    static let caption = Font.custom(barlowSemiBoldName, size: 13, relativeTo: .caption)
    static let hudNumber = Font.custom(barlowSemiBoldName, fixedSize: 15).monospacedDigit()
    static let countdown = Font.custom(alfaName, fixedSize: 160)
    static let countdownDraw = Font.custom(alfaName, fixedSize: 96)

    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
    static let sideMargin: CGFloat = 24
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1)
    }
}

/// Buttons of GUI.md §2: primary (cream fill), secondary (night 50 %), tertiary (text only).
struct ThemeButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case tertiary(Color)
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(Theme.button)
            .tracking(20 * 0.12)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(foreground)
            .padding(.horizontal, Theme.s4)
            .frame(maxWidth: isTertiary ? nil : .infinity)
            .frame(height: isTertiary ? 44 : 56)
            .background(background, in: Capsule())
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(pressed ? 0.85 : 1)
            .animation(.easeOut(duration: pressed ? 0.08 : 0.16), value: pressed)
    }

    private var isTertiary: Bool {
        if case .tertiary = kind { return true }
        return false
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.night
        case .secondary: return Theme.cream
        case .tertiary(let color): return color
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return Theme.cream
        case .secondary: return Theme.night.opacity(0.5)
        case .tertiary: return .clear
        }
    }
}

/// Fade-in of one piece of a screen after a transition (GUI.md §6): opacity 0 -> 1 and
/// y +12 -> 0 over `uiFadeInMs`, delayed `index * uiStaggerMs`.
struct Reveal: ViewModifier {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int

    func body(content: Content) -> some View {
        let tuning = model.dev.tuning
        return content
            .opacity(model.revealed ? 1 : 0)
            .offset(y: model.revealed || reduceMotion ? 0 : 12 * model.revealDirection)
            .animation(
                .timingCurve(0, 0, 0.2, 1, duration: tuning.uiFadeInMs / 1000)
                    .delay(Double(index) * tuning.uiStaggerMs / 1000),
                value: model.revealed)
    }
}

extension View {
    func reveal(_ model: AppModel, _ index: Int) -> some View {
        modifier(Reveal(model: model, index: index))
    }
}
