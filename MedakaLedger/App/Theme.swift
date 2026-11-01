import SwiftUI
import UIKit

// テーマ（DECISIONS.md 付録1）。主題は「飼育者の台帳」。生成りの紙に墨の文字、藍に近い青緑のインク、朱の判子。
// 色は全て Assets の色セット（ライトとダークを別に設計）。

enum Theme {
    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 12
    static let screenPadding: CGFloat = 16
    static let minButtonHeight: CGFloat = 48

    /// アセットを名前で直接読む。システムの既定色（青）に戻らないようにする。
    static let accent = Color("AccentColor")
    static let background = Color("ThemeBackground")
    static let surface = Color("ThemeSurface")
    static let deep = Color("ThemeDeep")
    static let warning = Color("ThemeWarning")
    static let caution = Color("ThemeAmber")
    static let done = Color("ThemeDone")
    /// 判子の朱。季節の印など、小さな印にだけ使う。文字の色には使わない。
    static let stamp = Color("ThemeStamp")
    /// 帳簿の罫線。
    static let rule = Color.primary.opacity(0.15)
}

/// 書体は2つ。見出しは明朝（台帳の見出しの手書きに近い）、本文はシステムの書体。
enum Typeface {
    /// 端末に入っているヒラギノ明朝。Dynamic Type に追従する。
    static func heading(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("HiraMinProN-W6", size: size, relativeTo: style)
    }
}

/// 全画面の題（ナビゲーションバー）を明朝にする。Dynamic Type に合わせて大きさが変わる。
enum Appearance {
    @MainActor
    static func apply() {
        func scaled(_ size: CGFloat, _ style: UIFont.TextStyle) -> UIFont? {
            guard let font = UIFont(name: "HiraMinProN-W6", size: size) else { return nil }
            return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
        }
        let bar = UINavigationBar.appearance()
        if let large = scaled(32, .largeTitle) {
            bar.largeTitleTextAttributes = [.font: large]
        }
        if let inline = scaled(17, .headline) {
            bar.titleTextAttributes = [.font: inline]
        }
    }
}

/// 主要な操作のボタン。高さ48pt以上（CLAUDE.md UIの決まり）。
/// 主はインクの塗り、従は紙の面に罫線の縁取り。
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
            .background(prominent ? Theme.accent : Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay {
                if !prominent {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.rule, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

/// 一覧や詳細で使うカードの背景。紙の面に罫線の縁。影は付けない。
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.rule, lineWidth: 1))
    }
}

/// 画面の背景。生成りの紙（ダークは墨）。リストとフォームの既定の背景は隠す。
struct ThemedBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Theme.background)
    }
}

/// 見出し。明朝で、右に件数などを小さく添えられる。
struct SectionHeading<Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typeface.heading(19, relativeTo: .headline))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing
        }
    }
}

extension SectionHeading where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.title = title
        self.trailing = EmptyView()
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }

    func cardBackground() -> some View {
        modifier(CardBackground())
    }
}
