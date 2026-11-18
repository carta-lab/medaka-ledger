import SwiftUI
import UIKit

// v2「水辺の余白」。色と余白の唯一の定義。保存・業務ロジックには触れない。
enum Theme {
    static let cornerRadius: CGFloat = 10
    static let cardPadding: CGFloat = 18
    static let screenPadding: CGFloat = 20
    static let minButtonHeight: CGFloat = 52
    static let accent = Color("AccentColor")
    static let background = Color("ThemeBackground")
    static let surface = Color("ThemeSurface")
    static let deep = Color("ThemeDeep")
    static let warning = Color("ThemeWarning")
    static let caution = Color("ThemeAmber")
    static let done = Color("ThemeDone")
    static let stamp = Color("ThemeStamp")
    static let ink = Color("ThemeInk")
    static let muted = Color("ThemeMuted")
    static let onAccent = Color("ThemeOnAccent")
    static let rule = Color("ThemeRule")
    static let wash = accent.opacity(0.07)
}

enum Typeface {
    static func heading(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("HiraMinProN-W3", size: size, relativeTo: style)
    }
}

enum Appearance {
    @MainActor
    static func apply() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = UIColor(named: "ThemeBackground")
        navigation.shadowColor = .clear
        let ink = UIColor(named: "ThemeInk") ?? .label
        if let font = UIFont(name: "HiraMinProN-W3", size: 30) {
            navigation.largeTitleTextAttributes = [
                .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: font),
                .foregroundColor: ink,
            ]
        }
        navigation.titleTextAttributes = [
            .font: UIFont.preferredFont(forTextStyle: .headline), .foregroundColor: ink,
        ]
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = navigation
        bar.scrollEdgeAppearance = navigation
        bar.compactAppearance = navigation

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(named: "ThemeSurface")
        tab.shadowColor = UIColor(named: "ThemeRule")
        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tab
        tabBar.scrollEdgeAppearance = tab
    }
}

struct LargeButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: Theme.minButtonHeight)
            .foregroundStyle(prominent ? Theme.onAccent : Theme.accent)
            .background(prominent ? Theme.accent : Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay {
                if !prominent {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.rule, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.4)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
    }
}

struct ThemedBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.defaultMinListRowHeight, Theme.minButtonHeight)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .foregroundStyle(Theme.ink)
            .tint(Theme.accent)
    }
}

/// List/Form の行にも共通の紙の色を指定する。親 View の背景だけでは行は変わらない。
struct LedgerRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Theme.surface)
            .listRowSeparatorTint(Theme.rule)
            .listRowInsets(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
    }
}

struct SectionHeading<Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                heading
                Spacer(minLength: 12)
                trailing
            }
            VStack(alignment: .leading, spacing: 8) {
                heading
                trailing
            }
        }
    }

    private var heading: some View {
        Text(title)
            .font(.headline.weight(.medium))
            .foregroundStyle(Theme.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeading where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.title = title
        self.trailing = EmptyView()
    }
}

extension View {
    func themedBackground() -> some View { modifier(ThemedBackground()) }
    func cardBackground() -> some View { modifier(CardBackground()) }
    func ledgerRow() -> some View { modifier(LedgerRowStyle()) }
}
