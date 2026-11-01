import SwiftUI

// 孵化の演出（DECISIONS.md J）。卵がゆれて割れ、針子が水面に広がる。2秒ほどで閉じる。
// 視差効果を減らす設定のときは、動かさずに結果だけを短く見せる。

struct HatchCelebration: View {
    let count: Int?
    let look: MedakaLook
    let onFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isWobbling = false
    @State private var isHatched = false

    private var fishCount: Int { min(max(count ?? 7, 1), 9) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    ripples
                    egg
                    fish
                }
                .frame(width: 260, height: 200)
                Text(verbatim: message)
                    .font(Typeface.heading(22, relativeTo: .title3))
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.screenPadding)
        }
        .sensoryFeedback(.success, trigger: isHatched)
        .task { await run() }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hatchCelebration")
    }

    private var message: String {
        if let count {
            return String(localized: "\(count.formatted())匹が孵りました")
        }
        return String(localized: "孵化を記録しました")
    }

    private var egg: some View {
        Ellipse()
            .fill(Color.white)
            .overlay(Ellipse().stroke(Theme.accent, lineWidth: 2))
            .frame(width: 40, height: 52)
            .rotationEffect(.degrees(isWobbling ? 9 : -9))
            .animation(motion(.easeInOut(duration: 0.15).repeatCount(6, autoreverses: true)), value: isWobbling)
            .scaleEffect(isHatched ? 1.7 : 1)
            .opacity(isHatched ? 0 : 1)
            .animation(motion(.easeOut(duration: 0.3)), value: isHatched)
    }

    private var ripples: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(Theme.accent.opacity(0.5), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(isHatched ? 4 : 0.3)
                    .opacity(isHatched ? 0 : 0.6)
                    .animation(motion(.easeOut(duration: 1.2).delay(Double(index) * 0.25)), value: isHatched)
            }
        }
    }

    private var fish: some View {
        ZStack {
            ForEach(0..<fishCount, id: \.self) { index in
                let angle = Double(index) * 2.39996
                let radius = 36 + 22 * Double(index).squareRoot()
                let dx = cos(angle) * radius * 1.2
                let dy = sin(angle) * radius * 0.8
                MedakaIcon(look: look, size: 36, showsBackground: false)
                    .scaleEffect(x: dx < 0 ? -1 : 1, y: 1)
                    .rotationEffect(.degrees(dy * 0.15))
                    .scaleEffect(isHatched ? 1 : 0.2)
                    .offset(x: isHatched ? dx : 0, y: isHatched ? dy : 0)
                    .opacity(isHatched ? 1 : 0)
                    .animation(motion(.spring(response: 0.6, dampingFraction: 0.6).delay(Double(index) * 0.04)), value: isHatched)
            }
        }
    }

    /// 視差効果を減らす設定のときは、動かさずに結果だけを見せる。
    private func motion(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }

    private func run() async {
        if reduceMotion {
            isHatched = true
            try? await Task.sleep(for: .seconds(0.8))
        } else {
            isWobbling = true
            try? await Task.sleep(for: .seconds(0.9))
            isHatched = true
            try? await Task.sleep(for: .seconds(1.4))
        }
        onFinished()
    }
}
