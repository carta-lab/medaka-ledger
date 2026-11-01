import SwiftUI
import UIKit

// ホームの見出し（DECISIONS.md 付録1、J）。水面の上に日付と季節を置く。
// Assets に HomeHero の画像があれば写真を、無ければ水面を描いて使う（IMAGES.md）。

struct HomeHero: View {
    let isBreedingSeason: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            Text(verbatim: Date.now.formatted(.dateTime.month().day().weekday()))
                .font(.largeTitle.bold())
            Label(isBreedingSeason ? LocalizedStringKey("産卵期") : LocalizedStringKey("産卵期外"), systemImage: isBreedingSeason ? "sun.max.fill" : "snowflake")
                .font(.subheadline.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.2), in: .capsule)
        }
        .foregroundStyle(Color.white)
        .padding(Theme.cardPadding + 4)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .bottomLeading)
        .background { WaterSurface() }
        .clipShape(.rect(cornerRadius: Theme.cornerRadius + 4))
        .accessibilityElement(children: .combine)
    }
}

/// 水面。写真があれば写真に、文字が読める暗さの影を重ねる。無ければ、深い青緑の水に光の揺らぎとめだかを描く。
struct WaterSurface: View {
    var body: some View {
        if let photo = UIImage(named: "HomeHero") {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .overlay(LinearGradient(colors: [.clear, Color.black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)
        } else {
            DrawnWater()
        }
    }
}

/// 写真の無いときの水面。光の揺らぎは静止、めだかだけがゆっくり泳ぐ。視差効果を減らす設定では泳がない。
private struct DrawnWater: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSwimming = false

    private static let fish: [(look: MedakaLook, x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (MedakaLook(shape: .standard, palette: .vermilion, hasSparkle: false, hasLongFin: false), 0.62, 0.30, 46),
        (MedakaLook(shape: .hikari, palette: .silver, hasSparkle: true, hasLongFin: false), 0.80, 0.52, 38),
        (MedakaLook(shape: .standard, palette: .orange, hasSparkle: false, hasLongFin: true), 0.50, 0.62, 32),
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(colors: [Theme.Tile.teal, Theme.deep], startPoint: .topTrailing, endPoint: .bottomLeading)
                // 水を通った光の揺らぎ
                ForEach(0..<5, id: \.self) { index in
                    Ellipse()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: size.width * 0.5, height: size.height * 0.35)
                        .rotationEffect(.degrees(Double(index) * 31))
                        .position(x: size.width * (0.25 + 0.17 * CGFloat(index)), y: size.height * (0.2 + 0.13 * CGFloat(index % 3)))
                }
                // 水面の波紋
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(Color.white.opacity(0.18 - Double(index) * 0.05), lineWidth: 1.5)
                        .frame(width: 70 + CGFloat(index) * 60, height: 70 + CGFloat(index) * 60)
                        .position(x: size.width * 0.82, y: size.height * 0.28)
                }
                ForEach(Array(Self.fish.enumerated()), id: \.offset) { index, item in
                    MedakaIcon(look: item.look, size: item.size, showsBackground: false)
                        .position(x: size.width * item.x, y: size.height * item.y)
                        .offset(x: isSwimming ? CGFloat(12 + index * 6) : 0, y: isSwimming ? CGFloat(index % 2 == 0 ? -4 : 4) : 0)
                }
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                isSwimming = true
            }
        }
    }
}

/// ホームの数字。容器、飼育中の群、匹数、育卵中のロット。
struct HomeStats: View {
    let tankCount: Int
    let tally: CohortTally
    let incubatingCount: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            tile(tankCount.formatted(), "容器", systemImage: "square.grid.2x2.fill", color: Theme.Tile.teal)
            tile(tally.cohortCount.formatted(), "飼育中の群", systemImage: "fish.fill", color: Theme.Tile.blue)
            tile(tally.fishCount.formatted() + (tally.hasUncounted ? "+" : ""), "飼育中の匹数", systemImage: "number", color: Theme.Tile.coral)
            tile(incubatingCount.formatted(), "育卵中のロット", systemImage: "circle.grid.3x3.fill", color: Theme.Tile.amber)
        }
    }

    private func tile(_ value: String, _ title: LocalizedStringKey, systemImage: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .opacity(0.85)
            Text(verbatim: value)
                .font(.system(.title, design: .rounded).bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption.bold())
                .opacity(0.9)
        }
        .foregroundStyle(Color.white)
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: .rect(cornerRadius: Theme.cornerRadius))
        .accessibilityElement(children: .combine)
    }
}
