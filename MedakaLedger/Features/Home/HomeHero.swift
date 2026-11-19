import SwiftUI

@MainActor
struct HomeHero: View {
    let isBreedingSeason: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WaterLandscape()
                .frame(height: 156)
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        date
                        Spacer(minLength: 12)
                        season
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        date
                        season
                    }
                }
                Text("水辺と暮らす、日々の記録。")
                    .font(Typeface.heading(21, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
            }
            .padding(20)
        }
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .accessibilityElement(children: .combine)
    }

    private var date: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: Date.now.formatted(.dateTime.year().weekday(.wide)))
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(verbatim: Date.now.formatted(.dateTime.month().day()))
                .font(Typeface.heading(32, relativeTo: .largeTitle))
        }
    }

    private var season: some View {
        LedgerStatus(
            text: isBreedingSeason ? String(localized: "産卵期") : String(localized: "産卵期外"),
            systemImage: isBreedingSeason ? "leaf" : "water.waves"
        )
    }
}

/// 数字は記録の要約。未計数をゼロと誤認させない。白い札に、縦の細い線で区切って並べる。
@MainActor
struct HomeLedgerSummary: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let tankCount: Int
    let tally: CohortTally
    let incubatingCount: Int

    private var metrics: [(title: LocalizedStringKey, value: String, unit: LocalizedStringKey)] {
        [
            ("容器", tankCount.formatted(), "個"),
            ("飼育中の群", tally.cohortCount.formatted(), "群"),
            ("匹数", tally.fishCount.formatted() + (tally.hasUncounted ? "+" : ""), "匹"),
            ("育卵中", incubatingCount.formatted(), "ロット"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 18) {
                    ForEach(Array(metrics.enumerated()), id: \.offset) { _, item in
                        metric(item.title, value: item.value, unit: item.unit)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(metrics.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Rectangle().fill(Theme.rule).frame(width: 1, height: 44)
                        }
                        metric(item.title, value: item.value, unit: item.unit)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            if tally.hasUncounted {
                Text("＋は未計数の群を含みます")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
        .accessibilityElement(children: .combine)
    }

    private func metric(_ title: LocalizedStringKey, value: String, unit: LocalizedStringKey) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption2).foregroundStyle(Theme.muted).lineLimit(1)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    number(value)
                    Text(unit).font(.caption2).foregroundStyle(Theme.muted)
                }
                VStack(spacing: 2) {
                    number(value)
                    Text(unit).font(.caption2).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func number(_ value: String) -> some View {
        Text(verbatim: value).font(Typeface.heading(26, relativeTo: .title2)).monospacedDigit().lineLimit(1)
    }
}

struct InkActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(InkActionLabelStyle())
            .frame(maxWidth: .infinity, minHeight: Theme.minButtonHeight)
            .padding(.vertical, 6)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
            .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.4)
    }
}

private struct InkActionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon.font(.title3.weight(.light)).foregroundStyle(Theme.accent)
            configuration.title.font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
