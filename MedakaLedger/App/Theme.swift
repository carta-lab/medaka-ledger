import SwiftUI

// テーマ（DECISIONS.md 付録1）。色は全て Assets の色セット（ライトとダークを別に設計）。

enum Theme {
    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 12
    static let screenPadding: CGFloat = 16
    static let minButtonHeight: CGFloat = 48

    static let accent = Color.accentColor
    static let background = Color("ThemeBackground")
    static let surface = Color("ThemeSurface")
    static let deep = Color("ThemeDeep")
    static let warning = Color("ThemeWarning")
    static let caution = Color("ThemeAmber")
    static let done = Color("ThemeDone")

    /// 白文字を載せる塗りの色（ホームの数字とクイック操作）。どれも白との対比4.5以上。
    enum Tile {
        static let teal = Color("TileTeal")
        static let blue = Color("TileBlue")
        static let coral = Color("TileCoral")
        static let amber = Color("TileAmber")
    }
}

/// 色で塗ったタイルのボタン。アイコンを上、文字を下に置く。高さ48pt以上。
struct TileButtonStyle: ButtonStyle {
    let color: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(TileLabelStyle())
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(color, in: .rect(cornerRadius: Theme.cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct TileLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6) {
            configuration.icon
                .font(.title2)
            configuration.title
                .font(.headline)
        }
        .padding(.vertical, 12)
    }
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
            .background(prominent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.accent.opacity(0.12)), in: .rect(cornerRadius: Theme.cornerRadius))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

/// 一覧や詳細で使うカードの背景。
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.accent.opacity(0.18), lineWidth: 1))
    }
}

/// 画面の背景。淡い水色（ダークは深い青黒）。リストとフォームの既定の背景は隠す。
struct ThemedBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Theme.background)
    }
}

/// ホームの見出しなど、深い青緑の面。文字は白。
struct DeepSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.white)
            .padding(Theme.cardPadding + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.deep, in: .rect(cornerRadius: Theme.cornerRadius))
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }

    func deepSurface() -> some View {
        modifier(DeepSurface())
    }

    func cardBackground() -> some View {
        modifier(CardBackground())
    }
}
