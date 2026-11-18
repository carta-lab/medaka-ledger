import SwiftUI

// ホームの見出し（DECISIONS.md 付録1、J）。台帳の一枚目のように、日付を明朝で大きく書き、季節を判子で押す。
// 右に、真上から見た睡蓮鉢を線で描く。動かさない。

struct HomeHero: View {
    let isBreedingSeason: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeLandscape()
                .frame(height: 200)
                .clipShape(.rect(cornerRadius: 0))
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: Date.now.formatted(.dateTime.month().day()))
                        .font(Typeface.heading(36, relativeTo: .largeTitle))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("水辺と暮らす、日々の記録。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                SeasonPill(isBreedingSeason: isBreedingSeason)
            }
            .padding(.horizontal, Theme.screenPadding)
        }
        .accessibilityElement(children: .contain)
    }
}

/// 季節の札。淡い若草色の丸い札に、深い緑の文字。
private struct SeasonPill: View {
    let isBreedingSeason: Bool

    var body: some View {
        Text(isBreedingSeason ? LocalizedStringKey("産卵期") : LocalizedStringKey("産卵期外"))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Theme.pill, in: .capsule)
    }
}

/// 水辺の風景。遠い山、近い山、水面、岩、葦、浮き葉、めだか。平らな色の重なりで描く。
/// 動かさない。ダークモードでは全体を少し暗くする。
private struct HomeLandscape: View {
    @Environment(\.colorScheme) private var colorScheme

    private static let sky = Color(red: 0.93, green: 0.94, blue: 0.86)
    private static let farHill = Color(red: 0.62, green: 0.72, blue: 0.60)
    private static let nearHill = Color(red: 0.36, green: 0.52, blue: 0.40)
    private static let water = Color(red: 0.55, green: 0.70, blue: 0.64)
    private static let waterDeep = Color(red: 0.43, green: 0.60, blue: 0.55)
    private static let rock = Color(red: 0.62, green: 0.63, blue: 0.60)
    private static let reed = Color(red: 0.55, green: 0.62, blue: 0.30)
    private static let leaf = Color(red: 0.50, green: 0.67, blue: 0.36)
    private static let sun = Color(red: 0.96, green: 0.80, blue: 0.50)

    private static let fish: [(look: MedakaLook, x: CGFloat, y: CGFloat, angle: Double, size: CGFloat)] = [
        (MedakaLook(shape: .standard, palette: .orange, hasSparkle: false, hasLongFin: false), 0.46, 0.70, -4, 40),
        (MedakaLook(shape: .standard, palette: .vermilion, hasSparkle: false, hasLongFin: false), 0.66, 0.78, 8, 34),
        (MedakaLook(shape: .hikari, palette: .orange, hasSparkle: false, hasLongFin: false), 0.34, 0.90, -10, 30),
    ]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack(alignment: .topLeading) {
                Self.sky
                Circle().fill(Self.sun)
                    .frame(width: 34, height: 34)
                    .position(x: w * 0.60, y: h * 0.17)
                hill(width: w, height: h, base: 0.46, peaks: [(0.05, 0.14), (0.38, 0.30), (0.78, 0.24)], color: Self.farHill)
                hill(width: w, height: h, base: 0.52, peaks: [(0.0, 0.34), (0.30, 0.44), (0.58, 0.40), (1.0, 0.30)], color: Self.nearHill.opacity(0.85))
                Rectangle().fill(Self.water)
                    .frame(width: w, height: h * 0.52)
                    .position(x: w / 2, y: h * 0.74)
                Rectangle().fill(Self.waterDeep.opacity(0.5))
                    .frame(width: w, height: h * 0.2)
                    .position(x: w / 2, y: h * 0.9)
                shore(width: w, height: h)
                pondLife(width: w, height: h)
                if colorScheme == .dark {
                    Color.black.opacity(0.35)
                }
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }

    /// 岩、葦、右の茂み。
    private func shore(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Ellipse().fill(Self.rock)
                    .frame(width: w * 0.20, height: h * 0.16)
                    .position(x: w * 0.10, y: h * 0.90)
                Ellipse().fill(Self.rock.opacity(0.9))
                    .frame(width: w * 0.20, height: h * 0.13)
                    .position(x: w * 0.92, y: h * 0.62)
                // 葦
                ForEach(0..<7, id: \.self) { index in
                    reedStem(index: index, width: w, height: h)
                }
                // 右の茂み
                ForEach(0..<4, id: \.self) { index in
                    Ellipse().fill(Self.nearHill.opacity(0.9))
                        .frame(width: w * 0.07, height: h * 0.12)
                        .rotationEffect(.degrees(Double(index) * 22 - 30))
                        .position(x: w * (0.90 + Double(index) * 0.025), y: h * (0.50 - Double(index % 2) * 0.04))
                }
        }
    }

    /// 浮き葉、波紋、めだか。
    private func pondLife(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            lily(width: w, height: h, x: 0.82, y: 0.82, size: 0.12)
                lily(width: w, height: h, x: 0.90, y: 0.90, size: 0.09)
                lily(width: w, height: h, x: 0.72, y: 0.93, size: 0.07)
                // 波紋
                ForEach(0..<2, id: \.self) { index in
                    Ellipse().stroke(Color.white.opacity(0.55), lineWidth: 1)
                        .frame(width: w * (0.18 + Double(index) * 0.08), height: h * (0.06 + Double(index) * 0.03))
                        .position(x: w * 0.55, y: h * 0.84)
                }
                ForEach(Array(Self.fish.enumerated()), id: \.offset) { _, item in
                    MedakaIcon(look: item.look, size: item.size, showsBackground: false, scalesWithText: false)
                        .rotationEffect(.degrees(item.angle))
                        .position(x: w * item.x, y: h * item.y)
                }
        }
    }

    private func hill(width: CGFloat, height: CGFloat, base: CGFloat, peaks: [(CGFloat, CGFloat)], color: Color) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: height * base + 2))
            for peak in peaks {
                path.addLine(to: CGPoint(x: width * peak.0, y: height * peak.1))
            }
            path.addLine(to: CGPoint(x: width, y: height * base + 2))
            path.closeSubpath()
        }
        .fill(color)
    }

    private func reedStem(index: Int, width: CGFloat, height: CGFloat) -> some View {
        let x = width * (0.03 + CGFloat(index) * 0.022)
        let top = height * (0.18 + CGFloat(index % 3) * 0.07)
        return Path { path in
            path.move(to: CGPoint(x: x, y: height * 0.86))
            path.addQuadCurve(to: CGPoint(x: x + width * 0.04, y: top), control: CGPoint(x: x - width * 0.01, y: height * 0.5))
        }
        .stroke(Self.reed, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
    }

    private func lily(width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat, size: CGFloat) -> some View {
        Ellipse().fill(Self.leaf)
            .frame(width: width * size, height: width * size * 0.45)
            .position(x: width * x, y: height * y)
    }
}

/// 台帳の頭の行。容器、飼育中の群、匹数、育卵中を、二重線の下に数字で並べる。
/// 文字が大きいときは2行2列にする。
struct HomeLedgerSummary: View {
    let tankCount: Int
    let tally: CohortTally
    let incubatingCount: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                    if index > 0 {
                        Rectangle().fill(Theme.rule).frame(width: 1).padding(.vertical, 4)
                    }
                    cellView(cell)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 12) {
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
        .padding(.vertical, 12)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.rule, lineWidth: 1))
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
        VStack(spacing: 2) {
            Text(cell.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: cell.value)
                    .font(Typeface.heading(26, relativeTo: .title2))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(cell.unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
    }
}

/// 記録するボタン。白い面に、緑の細い線の記号と名前を横に並べる。
struct InkActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(InkActionLabelStyle())
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.rule, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
    }
}

private struct InkActionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .font(.title2.weight(.light))
                .foregroundStyle(Theme.accent)
            configuration.title
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
    }
}
