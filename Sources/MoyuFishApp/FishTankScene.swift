import SwiftUI

/// Vector artwork, drawn in a 324 × 172 coordinate space so the aquarium stays crisp at Retina scale.
struct FishTankScene: View {
    var phase: Double
    var waterTime: Double
    var resting: Bool
    var angry: Bool = false
    var reduceMotion: Bool
    var celebrationElapsed: Double?
    @Environment(\.colorScheme) private var colorScheme

    private let ink = Color(red: 0.18, green: 0.36, blue: 0.39)
    private let orange = Color(red: 1, green: 0.62, blue: 0.24)
    private let finColor = Color(red: 0.98, green: 0.43, blue: 0.22)
    private let fishOutline = Color(red: 0.65, green: 0.31, blue: 0.17)

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 324, y: size.height / 172)
            drawTank(in: &context)
        }
    }

    private func drawTank(in context: inout GraphicsContext) {
        let dark = colorScheme == .dark
        let tank = Path(roundedRect: CGRect(x: 10, y: 15, width: 304, height: 146), cornerRadius: 22)
        context.fill(tank, with: .color(dark ? Color(red: 0.16, green: 0.25, blue: 0.27) : Color(red: 0.93, green: 0.98, blue: 0.98)))

        var underwater = context
        underwater.clip(to: tank)
        let surface = waterPath(y: 47, amplitude: 2.5, time: waterTime * 1.3)
        underwater.fill(surface, with: .color(dark ? Color(red: 0.20, green: 0.46, blue: 0.52) : Color(red: 0.66, green: 0.88, blue: 0.93)))
        underwater.fill(waterPath(y: 122, amplitude: 6, time: 1.5), with: .color(dark ? Color(red: 0.19, green: 0.41, blue: 0.46) : Color(red: 0.57, green: 0.82, blue: 0.86)))

        // A sandy floor and a few pebbles ground the fish in a real little habitat.
        underwater.fill(Path(ellipseIn: CGRect(x: -8, y: 143, width: 340, height: 40)), with: .color(Color(red: 0.85, green: 0.85, blue: 0.69)))
        drawPlant(in: &underwater, x: 49, y: 148, scale: 1, flip: false)
        drawPlant(in: &underwater, x: 277, y: 148, scale: 0.76, flip: true)
        for (x, y, width) in [(71.0, 150.0, 15.0), (91, 154, 9), (238, 151, 17), (255, 155, 9), (155, 154, 6)] {
            underwater.fill(Path(ellipseIn: CGRect(x: x, y: y, width: width, height: width * 0.42)), with: .color(ink.opacity(0.28)))
        }
        drawBubbles(in: &underwater)
        // Waterline sits behind the fish so a milestone can leap above it.
        var waveLine = Path()
        for i in 0...76 {
            let x = 10 + Double(i) * 4
            let point = CGPoint(x: x, y: 47 + sin(x / 32 + waterTime * 1.3) * 2.5)
            if i == 0 { waveLine.move(to: point) } else { waveLine.addLine(to: point) }
        }
        context.stroke(waveLine, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Glass edges and short reflections, kept off the face of the fish.
        context.stroke(tank, with: .color(dark ? Color(red: 0.48, green: 0.69, blue: 0.71) : Color(red: 0.44, green: 0.65, blue: 0.68)), lineWidth: 2.5)
        let rim = Path(ellipseIn: CGRect(x: 10, y: 9, width: 304, height: 18))
        context.fill(rim, with: .color(dark ? Color(red: 0.20, green: 0.31, blue: 0.33) : Color(red: 0.95, green: 0.99, blue: 0.99)))
        context.stroke(rim, with: .color(dark ? Color(red: 0.48, green: 0.69, blue: 0.71) : Color(red: 0.44, green: 0.65, blue: 0.68)), lineWidth: 2.5)
        stroke(&context, points: [CGPoint(x: 21, y: 42), CGPoint(x: 21, y: 78)], color: .white.opacity(0.65), width: 4)
        stroke(&context, points: [CGPoint(x: 21, y: 88), CGPoint(x: 21, y: 96)], color: .white.opacity(0.65), width: 4)
        stroke(&context, points: [CGPoint(x: 303, y: 113), CGPoint(x: 303, y: 135)], color: .white.opacity(0.45), width: 3)

        let leapProgress = celebrationElapsed.map { min(1, max(0, $0 / 1.8)) } ?? 0
        let leaping = celebrationElapsed != nil && !reduceMotion
        let lift = leaping ? sin(leapProgress * .pi) * 65 : 0
        let x = 164 + sin(phase) * 49
        let y = 100 + (resting ? 0 : sin(phase * 2) * 4) - lift
        var fish = context
        fish.translateBy(x: x, y: y)
        // Switch directly between two full-size side views at each end of the lap.
        let direction = reduceMotion ? 1 : cos(phase)
        fish.scaleBy(x: direction >= 0 ? 1 : -1, y: 1)
        fish.rotate(by: .degrees(leaping ? -cos(leapProgress * .pi) * 16 : sin(phase * 2) * 3))
        if leaping { drawSplash(in: &context, x: x, progress: leapProgress) }
        drawFish(in: &fish)
        if resting {
            context.draw(Text("z").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(ink), at: CGPoint(x: x + (direction >= 0 ? 39 : -39), y: y - 30))
        }

    }

    private func waterPath(y: Double, amplitude: Double, time: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 8, y: 164))
        for i in 0...77 {
            let x = 8 + Double(i) * 4
            path.addLine(to: CGPoint(x: x, y: y + sin(x / 32 + time) * amplitude))
        }
        path.addLine(to: CGPoint(x: 316, y: 164))
        path.closeSubpath()
        return path
    }

    private func drawPlant(in context: inout GraphicsContext, x: Double, y: Double, scale: Double, flip: Bool) {
        var plant = context
        plant.translateBy(x: x, y: y)
        plant.scaleBy(x: flip ? -scale : scale, y: scale)
        let sway = sin(waterTime * 1.2) * 3
        for (offset, height, lean) in [(-10.0, 32.0, -15.0), (0, 49, 4), (10, 27, 19)] {
            var leaf = Path()
            leaf.move(to: CGPoint(x: offset, y: 0))
            leaf.addQuadCurve(to: CGPoint(x: lean + sway, y: -height), control: CGPoint(x: offset - 18, y: -height * 0.7))
            leaf.addQuadCurve(to: CGPoint(x: offset + 4, y: 0), control: CGPoint(x: offset + 17, y: -height * 0.65))
            leaf.closeSubpath()
            plant.fill(leaf, with: .color(offset == 0 ? Color(red: 0.28, green: 0.60, blue: 0.46) : Color(red: 0.39, green: 0.70, blue: 0.52)))
        }
    }

    private func drawBubbles(in context: inout GraphicsContext) {
        for i in 0..<6 {
            let index = Double(i)
            let travel = (waterTime * 13 + index * 19).truncatingRemainder(dividingBy: 84)
            let x = (i.isMultiple(of: 2) ? 251.0 : 83.0) + sin(index * 2 + waterTime) * 5
            let y = 137 - travel
            let radius = i.isMultiple(of: 3) ? 4.0 : 2.5
            let bubble = Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2))
            context.fill(bubble, with: .color(.white.opacity(0.13)))
            context.stroke(bubble, with: .color(.white.opacity(0.70)), lineWidth: 1.2)
            context.fill(Path(ellipseIn: CGRect(x: x + 2, y: y + 1.5, width: 2, height: 2)), with: .color(.white.opacity(0.9)))
        }
    }

    private func drawFish(in context: inout GraphicsContext) {
        let wiggle = resting || reduceMotion ? 0 : sin(phase * 8) * 4
        let annoyed = angry && !resting
        var tail = Path()
        tail.move(to: CGPoint(x: -24, y: 0))
        tail.addCurve(to: CGPoint(x: -57, y: -19 + wiggle), control1: CGPoint(x: -43, y: -4), control2: CGPoint(x: -51, y: -27 + wiggle))
        tail.addQuadCurve(to: CGPoint(x: -55, y: 0), control: CGPoint(x: -65, y: -12))
        tail.addQuadCurve(to: CGPoint(x: -57, y: 20 + wiggle), control: CGPoint(x: -65, y: 15))
        tail.addCurve(to: CGPoint(x: -24, y: 0), control1: CGPoint(x: -49, y: 26 + wiggle), control2: CGPoint(x: -38, y: 4))
        fillOutlined(&context, tail, color: finColor)
        stroke(&context, points: [CGPoint(x: -52, y: -10), CGPoint(x: -32, y: 0), CGPoint(x: -52, y: 10)], color: fishOutline.opacity(0.6), width: 1.4)

        var dorsal = Path()
        dorsal.move(to: CGPoint(x: -17, y: -17))
        dorsal.addQuadCurve(to: CGPoint(x: -5, y: -33), control: CGPoint(x: -15, y: -34))
        dorsal.addQuadCurve(to: CGPoint(x: 16, y: -18), control: CGPoint(x: 14, y: -31))
        fillOutlined(&context, dorsal, color: finColor)
        let body = Path(ellipseIn: CGRect(x: -32, y: -24, width: 68, height: 49))
        fillOutlined(&context, body, color: orange)
        var belly = context
        belly.clip(to: body)
        belly.fill(Path(ellipseIn: CGRect(x: -22, y: 5, width: 59, height: 26)), with: .color(Color(red: 1, green: 0.83, blue: 0.46)))
        context.fill(Path(ellipseIn: CGRect(x: -20, y: -18, width: 18, height: 7)), with: .color(Color(red: 1, green: 0.79, blue: 0.43)))
        var fin = Path()
        let finX = -9.0
        fin.move(to: CGPoint(x: finX, y: 2))
        fin.addQuadCurve(to: CGPoint(x: finX - 8, y: 16 + wiggle * 0.4), control: CGPoint(x: finX - 19, y: 6))
        fin.addQuadCurve(to: CGPoint(x: finX, y: 2), control: CGPoint(x: finX + 3, y: 19))
        fillOutlined(&context, fin, color: finColor, width: 1.5)

        drawEye(in: &context, center: 18, width: 22, annoyed: annoyed, browDirection: 1)
        context.fill(Path(ellipseIn: CGRect(x: 11, y: 9, width: 10, height: 5)), with: .color(Color(red: 0.98, green: 0.44, blue: 0.33).opacity(0.65)))
        var mouth = Path()
        let mouthX = 30.0
        mouth.move(to: CGPoint(x: mouthX - 5, y: 13))
        mouth.addQuadCurve(to: CGPoint(x: mouthX + 4, y: 12), control: CGPoint(x: mouthX, y: annoyed ? 5 : 19))
        context.stroke(mouth, with: .color(fishOutline), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func drawEye(in context: inout GraphicsContext, center: Double, width: Double, annoyed: Bool, browDirection: Double) {
        if resting {
            var eyelid = Path()
            eyelid.move(to: CGPoint(x: center - width * 0.4, y: -5))
            eyelid.addQuadCurve(to: CGPoint(x: center + width * 0.4, y: -5), control: CGPoint(x: center, y: 3))
            context.stroke(eyelid, with: .color(ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            return
        }
        let eye = Path(ellipseIn: CGRect(x: center - width / 2, y: -18, width: width, height: 25))
        context.fill(eye, with: .color(Color(red: 1, green: 0.99, blue: 0.93)))
        context.stroke(eye, with: .color(fishOutline), lineWidth: 1.5)
        context.fill(Path(ellipseIn: CGRect(x: center - 3, y: -13, width: 9, height: 15)), with: .color(ink))
        context.fill(Path(ellipseIn: CGRect(x: center - 1, y: -12, width: 3.5, height: 4.5)), with: .color(.white))
        if annoyed {
            var lid = Path()
            let left = CGPoint(x: center - width / 2 - 1, y: -12 - browDirection * 5)
            let right = CGPoint(x: center + width / 2 + 1, y: -12 + browDirection * 5)
            lid.move(to: left)
            lid.addLine(to: right)
            lid.addLine(to: CGPoint(x: right.x, y: -22))
            lid.addLine(to: CGPoint(x: left.x, y: -22))
            lid.closeSubpath()
            var clipped = context
            clipped.clip(to: eye)
            clipped.fill(lid, with: .color(orange))
            stroke(&context, points: [left, right], color: fishOutline, width: 3)
        }
    }

    private func drawSplash(in context: inout GraphicsContext, x: Double, progress: Double) {
        let opacity = sin(progress * .pi)
        let radius = 10 + progress * 34
        context.stroke(Path(ellipseIn: CGRect(x: x - radius, y: 44, width: radius * 2, height: 7)), with: .color(.white.opacity(opacity)), lineWidth: 2)
        for i in 0..<5 {
            let offset = Double(i - 2)
            let height = sin(progress * .pi) * (23 - abs(offset) * 4)
            let rect = CGRect(x: x + offset * (9 + progress * 14), y: 44 - height, width: 3.5, height: 6)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
        }
    }

    private func fillOutlined(_ context: inout GraphicsContext, _ path: Path, color: Color, width: Double = 2) {
        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(fishOutline), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func stroke(_ context: inout GraphicsContext, points: [CGPoint], color: Color, width: Double) {
        var path = Path()
        for (index, point) in points.enumerated() {
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

}
