import SwiftUI

/// 日本の里山と静かな水面を、画面サイズに合わせて描くオリジナルの水景。
/// 通信・画像読み込み・タイマーを使わない。装飾なので VoiceOver の読み上げ対象外。
@MainActor
struct WaterLandscape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let sky = Color("LandscapeSky")
            let water = Color("LandscapeWater")
            let mountain = Color("LandscapeMountain")
            let bank = Color("LandscapeBank")
            let reed = Color("LandscapeReed")
            let light = Color("LandscapeLight")

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(sky))
            context.fill(
                Path(ellipseIn: CGRect(x: w * 0.20, y: h * 0.13, width: h * 0.18, height: h * 0.18)),
                with: .color(Color(red: 0.97, green: 0.80, blue: 0.50).opacity(0.95))
            )

            // 遠景の山。輪郭を段階的に薄くして空気の層を作る。
            var far = Path()
            far.move(to: CGPoint(x: 0, y: h * 0.49))
            far.addCurve(to: CGPoint(x: w * 0.42, y: h * 0.47),
                         control1: CGPoint(x: w * 0.12, y: h * 0.03),
                         control2: CGPoint(x: w * 0.22, y: h * 0.35))
            far.addCurve(to: CGPoint(x: w, y: h * 0.36),
                         control1: CGPoint(x: w * 0.72, y: h * 0.14),
                         control2: CGPoint(x: w * 0.77, y: h * 0.30))
            far.addLine(to: CGPoint(x: w, y: h * 0.64))
            far.addLine(to: CGPoint(x: 0, y: h * 0.64))
            far.closeSubpath()
            context.fill(far, with: .color(mountain.opacity(0.42)))

            var near = Path()
            near.move(to: CGPoint(x: 0, y: h * 0.47))
            near.addCurve(to: CGPoint(x: w * 0.55, y: h * 0.58),
                          control1: CGPoint(x: w * 0.18, y: h * 0.25),
                          control2: CGPoint(x: w * 0.31, y: h * 0.58))
            near.addCurve(to: CGPoint(x: w, y: h * 0.42),
                          control1: CGPoint(x: w * 0.74, y: h * 0.56),
                          control2: CGPoint(x: w * 0.86, y: h * 0.31))
            near.addLine(to: CGPoint(x: w, y: h * 0.72))
            near.addLine(to: CGPoint(x: 0, y: h * 0.72))
            near.closeSubpath()
            context.fill(near, with: .color(mountain.opacity(0.75)))

            // 水面。下半分に広い余白を残す。
            var pond = Path()
            pond.move(to: CGPoint(x: 0, y: h * 0.62))
            pond.addCurve(to: CGPoint(x: w, y: h * 0.59),
                          control1: CGPoint(x: w * 0.35, y: h * 0.55),
                          control2: CGPoint(x: w * 0.68, y: h * 0.66))
            pond.addLine(to: CGPoint(x: w, y: h))
            pond.addLine(to: CGPoint(x: 0, y: h))
            pond.closeSubpath()
            context.fill(pond, with: .color(water))

            for index in 0..<18 {
                let y = h * (0.63 + CGFloat(index) * 0.021)
                let x = CGFloat((index * 37) % 79) / 100 * w
                let length = w * (0.06 + CGFloat(index % 4) * 0.035)
                var ripple = Path()
                ripple.move(to: CGPoint(x: x, y: y))
                ripple.addQuadCurve(to: CGPoint(x: min(w, x + length), y: y),
                                    control: CGPoint(x: x + length / 2, y: y + 1.2))
                context.stroke(ripple, with: .color(light.opacity(0.42)),
                               style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            }

            // 左の岸と、右から水面へ垂れる草。
            var shore = Path()
            shore.move(to: CGPoint(x: 0, y: h * 0.59))
            shore.addCurve(to: CGPoint(x: w * 0.29, y: h * 0.67),
                           control1: CGPoint(x: w * 0.10, y: h * 0.54),
                           control2: CGPoint(x: w * 0.15, y: h * 0.65))
            shore.addQuadCurve(to: CGPoint(x: 0, y: h * 0.77),
                               control: CGPoint(x: w * 0.14, y: h * 0.70))
            shore.closeSubpath()
            context.fill(shore, with: .color(bank))

            for index in 0..<12 {
                let startX = w * (0.85 + CGFloat(index) * 0.016)
                let endX = startX - w * (0.05 + CGFloat(index % 4) * 0.018)
                var stem = Path()
                stem.move(to: CGPoint(x: startX, y: -4))
                stem.addQuadCurve(to: CGPoint(x: endX, y: h * (0.30 + CGFloat(index % 5) * 0.055)),
                                  control: CGPoint(x: startX - w * 0.1, y: h * 0.13))
                context.stroke(stem, with: .color(reed.opacity(0.5)),
                               style: StrokeStyle(lineWidth: 1, lineCap: .round))
                for leaf in 1...4 {
                    let t = CGFloat(leaf) / 5
                    let x = startX + (endX - startX) * t - w * 0.02
                    let y = h * (0.03 + t * 0.25)
                    var shape = Path()
                    shape.move(to: CGPoint(x: x, y: y))
                    shape.addQuadCurve(to: CGPoint(x: x - w * 0.025, y: y + h * 0.065),
                                       control: CGPoint(x: x - w * 0.035, y: y + h * 0.02))
                    shape.addQuadCurve(to: CGPoint(x: x, y: y),
                                       control: CGPoint(x: x - w * 0.002, y: y + h * 0.04))
                    context.fill(shape, with: .color(reed.opacity(0.55)))
                }
            }

            // 手前の小さな睡蓮の葉。
            let leaves: [(CGFloat, CGFloat, CGFloat)] = [(0.77, 0.86, 0.045), (0.85, 0.91, 0.028), (0.71, 0.94, 0.022)]
            for (x, y, radius) in leaves {
                let rect = CGRect(x: w * x, y: h * y, width: w * radius, height: w * radius * 0.4)
                context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.55, green: 0.72, blue: 0.38).opacity(0.9)))
            }
            fish(in: context, at: CGPoint(x: w * 0.46, y: h * 0.82), length: w * 0.042, angle: -0.2, color: Color(red: 0.93, green: 0.50, blue: 0.20))
            fish(in: context, at: CGPoint(x: w * 0.55, y: h * 0.87), length: w * 0.033, angle: 0.4, color: Color(red: 0.90, green: 0.40, blue: 0.18))
        }
        .accessibilityHidden(true)
    }

    private func fish(in context: GraphicsContext, at point: CGPoint, length: CGFloat, angle: Double, color: Color) {
        var layer = context
        layer.translateBy(x: point.x, y: point.y)
        layer.rotate(by: .radians(angle))
        let body = CGRect(x: -length / 2, y: -length * 0.14, width: length, height: length * 0.28)
        layer.fill(Path(ellipseIn: body), with: .color(color))
        var tail = Path()
        tail.move(to: CGPoint(x: -length * 0.4, y: 0))
        tail.addLine(to: CGPoint(x: -length * 0.8, y: -length * 0.22))
        tail.addLine(to: CGPoint(x: -length * 0.8, y: length * 0.22))
        tail.closeSubpath()
        layer.fill(tail, with: .color(color.opacity(0.7)))
    }
}
