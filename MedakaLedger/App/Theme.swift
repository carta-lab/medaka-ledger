import SwiftUI

// テーマ（DECISIONS.md 付録1）。アクセント色は Assets の AccentColor（朱赤）。

enum Theme {
    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 12
    static let screenPadding: CGFloat = 16
    static let minButtonHeight: CGFloat = 48

    static let accent = Color.accentColor
    static let warning = Color.red
    static let done = Color.green
}

/// 主要な操作のボタン。高さ48pt以上（CLAUDE.md UIの決まり）。
struct LargeButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled

    init(prominent: Bool = true) {
        self.prominent = prominent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: Theme.minButtonHeight)
            .padding(.horizontal, 8)
            .foregroundStyle(prominent ? Color.white : Theme.accent)
            .background(prominent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.fill.tertiary), in: .rect(cornerRadius: Theme.cornerRadius))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

/// 一覧や詳細で使うカードの背景。
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.quaternary, in: .rect(cornerRadius: Theme.cornerRadius))
    }
}

extension View {
    func cardBackground() -> some View {
        modifier(CardBackground())
    }
}
