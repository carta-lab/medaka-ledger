import SwiftUI

/// 各台帳の冒頭。装飾と実際の記録を混ぜない、短い説明と現在の件数。
@MainActor
struct LedgerIntro: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    var summary: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                LedgerSymbol(systemImage: systemImage)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(Typeface.heading(24, relativeTo: .title2))
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let summary {
                Text(verbatim: summary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

@MainActor
struct LedgerSymbol: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.light))
            .foregroundStyle(Theme.accent)
            .frame(width: 44, height: 44)
            .background(Theme.wash, in: .rect(cornerRadius: 12))
            .accessibilityHidden(true)
    }
}

@MainActor
struct LedgerStatus: View {
    let text: String
    var color: Color = Theme.accent
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(verbatim: text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.08), in: .rect(cornerRadius: 5))
        .fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
struct LedgerEmptyState: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    let actionTitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WaterLandscape().frame(height: 160).clipShape(.rect(cornerRadius: Theme.cornerRadius))
                LedgerIntro(title: title, subtitle: message, systemImage: systemImage)
                Button(actionTitle, action: action).buttonStyle(LargeButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
    }
}

/// 入力画面の冒頭。入力と保存そのものは既存の各 Feature に任せる。
@MainActor
struct EntryHeading: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Section {
            LedgerIntro(title: title, subtitle: subtitle, systemImage: systemImage)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
        }
    }
}
