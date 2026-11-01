import SwiftUI

// ホームの見出し（DECISIONS.md 付録1、J）。台帳の一枚目のように、日付を明朝で大きく書き、季節を判子で押す。
// 右に、真上から見た睡蓮鉢を線で描く。動かさない。

struct HomeHero: View {
    let isBreedingSeason: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: Date.now.formatted(.dateTime.year()))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(verbatim: Date.now.formatted(.dateTime.month().day()))
                    .font(Typeface.heading(40, relativeTo: .largeTitle))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(verbatim: Date.now.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                SeasonStamp(isBreedingSeason: isBreedingSeason)
                    .padding(.top, 10)
            }
            Spacer(minLength: 0)
            PondSketch()
                .frame(width: 128, height: 128)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

/// 季節の判子。朱の枠に明朝の文字。わずかに傾けて、手で押した印にする。
private struct SeasonStamp: View {
    let isBreedingSeason: Bool

    var body: some View {
        Text(isBreedingSeason ? LocalizedStringKey("産卵期") : LocalizedStringKey("産卵期外"))
            .font(Typeface.heading(15, relativeTo: .subheadline))
            .foregroundStyle(Theme.stamp)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.stamp, lineWidth: 1.5))
            .rotationEffect(.degrees(-3))
    }
}

/// 真上から見た睡蓮鉢。縁は二重の細い線、水は淡いインク、浮き葉とめだか。
private struct PondSketch: View {
    private static let fish: [(look: MedakaLook, x: CGFloat, y: CGFloat, angle: Double, size: CGFloat)] = [
        (MedakaLook(shape: .standard, palette: .vermilion, hasSparkle: false, hasLongFin: false), 0.42, 0.58, -24, 44),
        (MedakaLook(shape: .hikari, palette: .silver, hasSparkle: true, hasLongFin: false), 0.62, 0.38, 150, 36),
    ]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(Theme.accent.opacity(0.08))
                    .padding(side * 0.08)
                Circle().stroke(Color.primary.opacity(0.55), lineWidth: 1.5)
                Circle().stroke(Color.primary.opacity(0.3), lineWidth: 0.8)
                    .padding(side * 0.08)
                LilyPad().fill(Theme.done.opacity(0.45))
                    .frame(width: side * 0.26, height: side * 0.26)
                    .rotationEffect(.degrees(30))
                    .position(x: side * 0.68, y: side * 0.70)
                LilyPad().fill(Theme.done.opacity(0.3))
                    .frame(width: side * 0.16, height: side * 0.16)
                    .rotationEffect(.degrees(-80))
                    .position(x: side * 0.30, y: side * 0.32)
                // 水面の小さな波紋
                Circle().trim(from: 0.05, to: 0.4)
                    .stroke(Theme.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    .frame(width: side * 0.22, height: side * 0.22)
                    .position(x: side * 0.30, y: side * 0.66)
                ForEach(Array(Self.fish.enumerated()), id: \.offset) { _, item in
                    MedakaIcon(look: item.look, size: item.size, showsBackground: false, scalesWithText: false)
                        .rotationEffect(.degrees(item.angle))
                        .position(x: side * item.x, y: side * item.y)
                }
            }
            .frame(width: side, height: side)
        }
        .accessibilityHidden(true)
    }
}

/// 切れ込みのある浮き葉。切れ込みは細く、葉の中心まで。
private struct LilyPad: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: .degrees(8), endAngle: .degrees(352), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// 台帳の頭の行。容器、飼育中の群、匹数、育卵中を、二重線の下に数字で並べる。
/// 文字が大きいときは2行2列にする。
struct HomeLedgerSummary: View {
    let tankCount: Int
    let tally: CohortTally
    let incubatingCount: Int

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Rectangle().fill(Color.primary.opacity(0.5)).frame(height: 1.5)
                Rectangle().fill(Theme.rule).frame(height: 1)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                        if index > 0 {
                            Rectangle().fill(Theme.rule).frame(width: 1)
                        }
                        cellView(cell)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 8) {
                    GridRow {
                        cellView(cells[0])
                        cellView(cells[1])
                    }
                    GridRow {
                        cellView(cells[2])
                        cellView(cells[3])
                    }
                }
            }
            .padding(.vertical, 10)
            Rectangle().fill(Theme.rule).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private struct Cell {
        var title: LocalizedStringKey
        var value: String
        var unit: LocalizedStringKey
    }

    private var cells: [Cell] {
        [
            Cell(title: "容器", value: tankCount.formatted(), unit: "個"),
            Cell(title: "飼育中の群", value: tally.cohortCount.formatted(), unit: "群"),
            Cell(title: "匹数", value: tally.fishCount.formatted() + (tally.hasUncounted ? "+" : ""), unit: "匹"),
            Cell(title: "育卵中", value: incubatingCount.formatted(), unit: "ロット"),
        ]
    }

    private func cellView(_ cell: Cell) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(cell.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: cell.value)
                    .font(Typeface.heading(24, relativeTo: .title2))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(cell.unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// クイック操作のボタン。紙の面に罫線の縁、細いインクの記号の下に名前。
struct InkActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(InkActionLabelStyle())
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.rule, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
    }
}

private struct InkActionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6) {
            configuration.icon
                .font(.title2.weight(.light))
                .foregroundStyle(Theme.accent)
            configuration.title
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 10)
    }
}
