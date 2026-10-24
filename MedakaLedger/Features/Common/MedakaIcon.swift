import SwiftUI

// めだかの絵（DECISIONS.md J）。系統の表現タグと品種名から見た目を決める、目印のイメージ。

extension Strain {
    var look: MedakaLook {
        MedakaLook.from(breedName: breedName, traitTags: traitTags)
    }
}

extension MedakaLook.Palette {
    /// ライトでもダークでも同じ色。絵の下地と輪郭で、どちらの背景でも見える。
    var color: Color {
        switch self {
        case .orange: Color(red: 0.95, green: 0.55, blue: 0.16)
        case .vermilion: Color(red: 0.85, green: 0.28, blue: 0.17)
        case .white: Color(red: 0.96, green: 0.95, blue: 0.91)
        case .black: Color(red: 0.17, green: 0.17, blue: 0.18)
        case .yellow: Color(red: 0.95, green: 0.76, blue: 0.19)
        case .silver: Color(red: 0.72, green: 0.78, blue: 0.82)
        case .redWhite, .tricolor: Color(red: 0.96, green: 0.95, blue: 0.91)
        case .amber: Color(red: 0.79, green: 0.54, blue: 0.17)
        case .blue: Color(red: 0.24, green: 0.47, blue: 0.70)
        case .plain: Color(red: 0.56, green: 0.66, blue: 0.68)
        }
    }
}

/// めだかの体の部分。右向き。
private struct MedakaPart: Shape {
    enum Part { case body, tail, dorsal, anal }

    let part: Part
    let look: MedakaLook

    func path(in rect: CGRect) -> Path {
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        let isDaruma = look.shape == .daruma
        let fin = look.hasLongFin ? 1.35 : 1.0
        let bodyTop = isDaruma ? 0.27 : 0.38
        let bodyBottom = isDaruma ? 0.73 : 0.62
        var path = Path()
        switch part {
        case .body:
            let left = isDaruma ? 0.34 : 0.30
            path.addEllipse(in: CGRect(
                x: rect.minX + rect.width * left, y: rect.minY + rect.height * bodyTop,
                width: rect.width * (0.92 - left), height: rect.height * (bodyBottom - bodyTop)
            ))
        case .tail:
            let base = isDaruma ? 0.36 : 0.32
            let reach = (isDaruma ? 0.14 : 0.24) * fin
            let spread = 0.17 * fin
            path.move(to: point(base, 0.5))
            path.addLine(to: point(base - reach, 0.5 - spread))
            path.addQuadCurve(to: point(base - reach, 0.5 + spread), control: point(base - reach * 0.55, 0.5))
            path.closeSubpath()
        case .dorsal:
            // ヒカリ体型は、背びれが尻びれと同じ大きさ、同じ位置にある形で描く
            let isMirrored = look.shape == .hikari
            let (start, end, height) = isMirrored ? (0.50, 0.76, 0.10 * fin) : (0.66, 0.80, 0.07 * fin)
            path.move(to: point(start, bodyTop + 0.02))
            path.addLine(to: point(end, bodyTop + 0.02))
            path.addLine(to: point(end - 0.04, bodyTop - height))
            path.closeSubpath()
        case .anal:
            let height = 0.10 * fin
            path.move(to: point(0.50, bodyBottom - 0.02))
            path.addLine(to: point(0.76, bodyBottom - 0.02))
            path.addLine(to: point(0.72, bodyBottom + height))
            path.closeSubpath()
        }
        return path
    }
}

struct MedakaIcon: View {
    let look: MedakaLook
    var size: CGFloat = 40
    var showsBackground = true
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let side = size * scale
        let color = look.palette.color
        ZStack {
            if showsBackground {
                RoundedRectangle(cornerRadius: side * 0.25)
                    .fill(Theme.accent.opacity(0.12))
            }
            MedakaPart(part: .tail, look: look).fill(color.opacity(0.8))
            MedakaPart(part: .dorsal, look: look).fill(color.opacity(0.8))
            MedakaPart(part: .anal, look: look).fill(color.opacity(0.8))
            MedakaPart(part: .body, look: look).fill(color)
            MedakaPart(part: .body, look: look).stroke(Color.primary.opacity(0.3), lineWidth: max(0.5, side / 64))
            patches(side: side)
            Circle().fill(Color.black.opacity(0.85))
                .frame(width: side * 0.07, height: side * 0.07)
                .position(x: side * 0.80, y: side * 0.47)
            if look.hasSparkle {
                ForEach(Array([(0.55, 0.45), (0.68, 0.53), (0.45, 0.53)].enumerated()), id: \.offset) { _, spot in
                    Circle().fill(Color.white.opacity(0.9))
                        .frame(width: side * 0.04, height: side * 0.04)
                        .position(x: side * spot.0, y: side * spot.1)
                }
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func patches(side: CGFloat) -> some View {
        let red = MedakaLook.Palette.vermilion.color
        switch look.palette {
        case .redWhite:
            Ellipse().fill(red)
                .frame(width: side * 0.22, height: side * 0.12)
                .position(x: side * 0.60, y: side * 0.44)
        case .tricolor:
            Ellipse().fill(red)
                .frame(width: side * 0.18, height: side * 0.11)
                .position(x: side * 0.62, y: side * 0.44)
            Circle().fill(Color.black.opacity(0.8))
                .frame(width: side * 0.06, height: side * 0.06)
                .position(x: side * 0.48, y: side * 0.54)
        default:
            EmptyView()
        }
    }
}
