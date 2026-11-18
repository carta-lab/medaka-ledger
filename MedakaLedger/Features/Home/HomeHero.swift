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

/// 数字は記録の要約。未計数をゼロと誤認させない。
@MainActor
struct HomeLedgerSummary: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let tankCount: Int
    let tally: CohortTally
    let incubatingCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading),
                                     count: dynamicTypeSize.isAccessibilitySize ? 2 : 4), spacing: 18) {
                metric("容器", value: tankCount.formatted(), unit: "個")
                metric("飼育中の群", value: tally.cohortCount.formatted(), unit: "群")
                metric("匹数", value: tally.fishCount.formatted() + (tally.hasUncounted ? "+" : ""), unit: "匹")
                metric("育卵中", value: incubatingCount.formatted(), unit: "ロット")
            }
            if tally.hasUncounted {
                Text("＋は未計数の群を含みます")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func metric(_ title: LocalizedStringKey, value: String, unit: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption2).foregroundStyle(Theme.muted)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    number(value)
                    Text(unit).font(.caption2).foregroundStyle(Theme.muted)
                }
                VStack(alignment: .leading, spacing: 2) {
                    number(value)
                    Text(unit).font(.caption2).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func number(_ value: String) -> some View {
        Text(verbatim: value).font(.title2.weight(.light)).monospacedDigit()
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
