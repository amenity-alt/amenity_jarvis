// JarvisAvatar.swift — 科幻风格 JARVIS 全息核心（光点粒子 → 六边形AI眼）+ 环境信息面板
// 用法: JarvisAvatar [--mode idle|listen|speak]
// stdin 命令: idle / listen / speak / show / hide / center / info:<json> / quit

import AppKit

struct Particle {
    var x: CGFloat
    var y: CGFloat
    var spawnX: CGFloat
    var spawnY: CGFloat
    var tx: CGFloat
    var ty: CGFloat
    var phase: Double
    var size: CGFloat
}

final class AvatarView: NSView {
    var mode = "idle"
    private var particles: [Particle] = []
    private var progress: CGFloat = 0
    private var showCore = false
    private var lastTime: TimeInterval = 0

    // 粒子分布
    private let HEX = 96      // 旋转六边形外框
    private let ARC = 80      // 反向光环
    private let EYE = 128     // 发光眼睛（上下弧）
    private let IRIS = 48     // 瞳孔
    private let SPOKE = 32    // 扫描辐条
    private let DUST = 36     // 漂浮光尘
    private var totalCount: Int { HEX + ARC + EYE + IRIS + SPOKE + DUST }

    override var isOpaque: Bool { false }

    private func smoothstep(_ p: CGFloat) -> CGFloat {
        let t = max(0, min(1, p))
        return t * t * (3 - 2 * t)
    }

    private func spawnParticles() {
        particles.removeAll()
        // 粒子从整个屏幕各处飞来
        var sx0: CGFloat = -600
        var sy0: CGFloat = -600
        var sx1: CGFloat = 1024
        var sy1: CGFloat = 768
        if let frame = window?.screen?.visibleFrame, let origin = window?.frame.origin {
            sx0 = frame.minX - origin.x - 80
            sy0 = frame.minY - origin.y - 80
            sx1 = frame.maxX - origin.x + 80
            sy1 = frame.maxY - origin.y + 80
        }
        func randomSpawn() -> (CGFloat, CGFloat) {
            (CGFloat.random(in: sx0 ... sx1), CGFloat.random(in: sy0 ... sy1))
        }
        func make(_ count: Int) -> [Particle] {
            (0..<count).map { _ in
                let (sx, sy) = randomSpawn()
                return Particle(x: sx, y: sy, spawnX: sx, spawnY: sy, tx: 0, ty: 0,
                                phase: Double.random(in: 0 ... .pi * 2),
                                size: CGFloat.random(in: 1.5 ... 3.4))
            }
        }
        particles.append(contentsOf: make(totalCount))
    }

    private func updateParticles(now: TimeInterval, dt: CGFloat) {
        if particles.isEmpty {
            spawnParticles()
            progress = 0
            showCore = false
        }
        let w = bounds.width
        let h = bounds.height
        let cx = w / 2
        let cy = h / 2
        let base = min(w, h)
        let rotation = CGFloat(now.truncatingRemainder(dividingBy: 8.0) / 8.0) * .pi * 2
        let pulse = CGFloat(0.85 + 0.15 * sin(now * 3.2))
        if progress >= 1 {
            showCore = true
        }

        for (index, particle) in particles.enumerated() {
            var tx = cx
            var ty = cy
            var driftX: CGFloat = 0
            var driftY: CGFloat = 0
            if showCore {
                (tx, ty, driftX, driftY) = coreTarget(index, cx: cx, cy: cy, base: base,
                                                      now: now, rotation: rotation, phase: particle.phase)
            } else {
                (tx, ty, driftX, driftY) = ringTarget(index, cx: cx, cy: cy, base: base,
                                                      now: now, rotation: rotation, pulse: pulse, phase: particle.phase)
            }
            let eased = smoothstep(progress)
            let targetX = particle.spawnX + (tx - particle.spawnX) * eased + driftX
            let targetY = particle.spawnY + (ty - particle.spawnY) * eased + driftY
            let k = min(1, dt * 7)
            particles[index].x += (targetX - particle.x) * k
            particles[index].y += (targetY - particle.y) * k
        }
        progress = min(1, progress + dt * 0.5)
    }

    // 环形态（组装阶段）
    private func ringTarget(_ i: Int, cx: CGFloat, cy: CGFloat, base: CGFloat,
                            now: TimeInterval, rotation: CGFloat, pulse: CGFloat, phase: Double) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        let ringEnd = 176
        let innerEnd = 304
        let coreEnd = 352
        var tx = cx
        var ty = cy
        if i < ringEnd {
            let angle = CGFloat(Double(i) / Double(ringEnd) * Double.pi * 2) + rotation
            var radius = base * 0.40
            if mode == "listen" {
                let wave = CGFloat(0.5 + 0.5 * sin(Double(i) * 1.9 + now * 9))
                radius = base * (0.28 + 0.16 * wave)
            } else if mode == "speak" {
                radius = base * (0.40 + 0.03 * sin(now * 6 + Double(i)))
            }
            tx = cx + cos(angle) * radius
            ty = cy + sin(angle) * radius
        } else if i < innerEnd {
            let j = i - ringEnd
            let angle = CGFloat(Double(j) / Double(innerEnd - ringEnd) * Double.pi * 2) - rotation * 1.4
            let radius = base * 0.24 * pulse
            tx = cx + cos(angle) * radius
            ty = cy + sin(angle) * radius
        } else if i < coreEnd {
            let j = i - innerEnd
            let angle = CGFloat(Double(j) / Double(coreEnd - innerEnd) * Double.pi * 2) + rotation * 0.4
            let radius = base * 0.06 * pulse
            tx = cx + cos(angle) * radius
            ty = cy + sin(angle) * radius
        } else {
            let j = i - coreEnd
            let speed = 0.3 + 0.1 * Double(j % 3)
            tx = cx + CGFloat(sin(now * speed + phase)) * base * 0.55
            ty = cy + CGFloat(cos(now * speed * 0.83 + phase * 1.3)) * base * 0.55
        }
        return (tx, ty, 0, 0)
    }

    // 科幻 AI 核心形态：六边形外框 + 反向光环 + 发光眼睛 + 瞳孔 + 扫描辐条
    private func coreTarget(_ i: Int, cx: CGFloat, cy: CGFloat, base: CGFloat,
                            now: TimeInterval, rotation: CGFloat, phase: Double) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        let hexEnd = HEX
        let arcEnd = hexEnd + ARC
        let eyeEnd = arcEnd + EYE
        let irisEnd = eyeEnd + IRIS
        let spokeEnd = irisEnd + SPOKE
        let eyeCy = cy + base * 0.03
        let pulse = CGFloat(0.85 + 0.15 * sin(now * 3.2))
        var tx = cx
        var ty = cy
        var dx: CGFloat = 0
        var dy: CGFloat = 0

        if i < hexEnd {
            // 旋转六边形外框：6 条边 × 16 点
            let edge = i / 16
            let t = CGFloat(i % 16) / 15
            let r = base * 0.44
            let a1 = CGFloat.pi / 2 + CGFloat(edge) * .pi / 3 + rotation
            let a2 = CGFloat.pi / 2 + CGFloat(edge + 1) * .pi / 3 + rotation
            tx = cx + (cos(a1) * r * (1 - t) + cos(a2) * r * t)
            ty = cy + (sin(a1) * r * (1 - t) + sin(a2) * r * t)
        } else if i < arcEnd {
            // 反向光环
            let j = i - hexEnd
            let angle = CGFloat(Double(j) / Double(ARC) * Double.pi * 2) - rotation * 1.6
            let r = base * 0.33
            tx = cx + cos(angle) * r
            ty = cy + sin(angle) * r
        } else if i < eyeEnd {
            // 发光眼睛（上下弧）
            let j = i - arcEnd
            if j < 64 {
                let t = CGFloat(j) / 63
                let a = CGFloat.pi * t
                tx = cx + cos(a) * base * 0.20
                ty = eyeCy + sin(a) * base * 0.075
            } else {
                let t = CGFloat(j - 64) / 63
                let a = CGFloat.pi + CGFloat.pi * t
                tx = cx + cos(a) * base * 0.20
                ty = eyeCy + sin(a) * base * 0.075
            }
            dy = CGFloat(sin(now * 2 + Double(j))) * base * 0.002
        } else if i < irisEnd {
            // 瞳孔（缓慢旋转的亮核）
            let j = i - eyeEnd
            let a = CGFloat(Double(j) / Double(IRIS) * Double.pi * 2) + rotation * 0.5
            let r = base * (0.042 + 0.020 * pulse + 0.010 * sin(now * 3 + Double(j)))
            tx = cx + cos(a) * r
            ty = eyeCy + sin(a) * r * 0.8
        } else if i < spokeEnd {
            // 扫描辐条：8 方向 × 4 点
            let j = i - irisEnd
            let dir = j / 4
            let k = j % 4
            let a = CGFloat(dir) * .pi / 4 + rotation * 0.7
            let r = base * (0.12 + 0.035 * CGFloat(k))
            tx = cx + cos(a) * r
            ty = eyeCy + sin(a) * r
        } else {
            // 漂浮光尘
            let j = i - spokeEnd
            let speed = 0.3 + 0.1 * Double(j % 3)
            tx = cx + CGFloat(sin(now * speed + phase)) * base * 0.64
            ty = cy + CGFloat(cos(now * speed * 0.83 + phase * 1.3)) * base * 0.64
            dx = CGFloat(sin(now * 1.1 + phase)) * base * 0.012
            dy = CGFloat(cos(now * 0.9 + phase)) * base * 0.012
        }
        return (tx, ty, dx, dy)
    }

    override func draw(_ dirtyRect: NSRect) {
        let now = Date().timeIntervalSinceReferenceDate
        let dt = lastTime == 0 ? 0 : CGFloat(now - lastTime)
        lastTime = now
        updateParticles(now: now, dt: dt)

        let w = bounds.width
        let h = bounds.height
        let cx = w / 2
        let cy = h / 2
        let base = min(w, h)

        // 背景：半透明深色圆盘
        let bg = NSBezierPath(ovalIn: NSRect(x: cx - base * 0.46, y: cy - base * 0.46,
                                             width: base * 0.92, height: base * 0.92))
        NSColor(calibratedWhite: 0.04, alpha: 0.55).setFill()
        bg.fill()

        // 模式特效
        if mode == "speak" {
            drawRipples(cx: cx, cy: cy, base: base, now: now)
        }

        // 光点粒子
        drawParticles()

        // JARVIS 文字（发光）
        drawLabel(cx: cx, cy: cy, base: base)
    }

    private func drawParticles() {
        let arcEnd = HEX + ARC
        let eyeEnd = arcEnd + EYE
        let irisEnd = eyeEnd + IRIS
        for (index, p) in particles.enumerated() {
            if showCore && index >= arcEnd && index < irisEnd {
                // 眼睛 + 瞳孔：亮白发光
                let glow = p.size * 4.5
                NSColor(calibratedRed: 0.55, green: 0.92, blue: 1.0, alpha: 0.25).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - glow / 2, y: p.y - glow / 2,
                                            width: glow, height: glow)).fill()
                let bright: CGFloat = index < eyeEnd ? 0.9 : 1.0
                NSColor(calibratedRed: bright, green: 0.99, blue: 1.0, alpha: 1).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - p.size * 0.85, y: p.y - p.size * 0.85,
                                            width: p.size * 1.7, height: p.size * 1.7)).fill()
            } else {
                let glow = p.size * 3.2
                NSColor(calibratedRed: 0.25, green: 0.78, blue: 1.0, alpha: 0.10).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - glow / 2, y: p.y - glow / 2,
                                            width: glow, height: glow)).fill()
                NSColor(calibratedRed: 0.55, green: 0.92, blue: 1.0, alpha: 0.95).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - p.size / 2, y: p.y - p.size / 2,
                                            width: p.size, height: p.size)).fill()
            }
        }
    }

    private func drawRipples(cx: CGFloat, cy: CGFloat, base: CGFloat, now: TimeInterval) {
        for i in 0..<3 {
            let t = (now * 0.9 + Double(i) / 3).truncatingRemainder(dividingBy: 1.0)
            let radius = base * CGFloat(0.18 + 0.36 * t)
            let alpha = CGFloat(1.0 - t)
            let path = NSBezierPath(ovalIn: NSRect(x: cx - radius, y: cy - radius,
                                                   width: radius * 2, height: radius * 2))
            NSColor(calibratedRed: 0.3, green: 0.85, blue: 1.0, alpha: alpha * 0.45).setStroke()
            path.lineWidth = base * 0.008
            path.stroke()
        }
    }

    private func drawLabel(cx: CGFloat, cy: CGFloat, base: CGFloat) {
        let text = "JARVIS" as NSString
        let font = NSFont(name: "Avenir Next Heavy", size: base * 0.085)
            ?? NSFont.systemFont(ofSize: base * 0.085, weight: .heavy)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedRed: 0.55, green: 0.92, blue: 1.0, alpha: 0.95),
            .kern: base * 0.03,
        ]
        let size = text.size(withAttributes: attrs)
        let labelY = showCore ? cy - base * 0.16 : cy - base * 0.36
        let origin = NSPoint(x: cx - size.width / 2, y: labelY)
        for (offset, alpha) in [(1.5, 0.25), (3.0, 0.15), (5.0, 0.08)] {
            let glowAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor(calibratedRed: 0.3, green: 0.8, blue: 1.0, alpha: alpha),
            ]
            text.draw(at: NSPoint(x: origin.x, y: origin.y + offset), withAttributes: glowAttrs)
        }
        text.draw(at: origin, withAttributes: attrs)
    }
}

// ---------- 全息信息面板（模块化卡片 + 环状图表） ----------

let PALETTE: [NSColor] = [
    NSColor(calibratedRed: 0.30, green: 0.85, blue: 1.00, alpha: 1),   // 青
    NSColor(calibratedRed: 0.65, green: 0.45, blue: 1.00, alpha: 1),   // 紫
    NSColor(calibratedRed: 0.35, green: 0.92, blue: 0.55, alpha: 1),   // 绿
    NSColor(calibratedRed: 1.00, green: 0.66, blue: 0.20, alpha: 1),   // 橙
    NSColor(calibratedRed: 1.00, green: 0.38, blue: 0.72, alpha: 1),   // 粉
    NSColor(calibratedRed: 1.00, green: 0.35, blue: 0.42, alpha: 1),   // 红
]

enum PanelModule {
    case keys(title: String, rows: [(String, String)], color: NSColor)
    case donuts(title: String, items: [(String, String, NSColor)])
    case gauges(title: String, items: [(String, String, NSColor)])
    case sparks(title: String, items: [(String, String, NSColor)])
    case convo(title: String, color: NSColor)
    case log(title: String, color: NSColor)
}

final class PanelView: NSView {
    var title = "JARVIS // 状态"
    var modules: [PanelModule] = []
    var info: [String: String] = [:]
    var log: [String] = []
    var convo: [String] = []

    override var isOpaque: Bool { false }

    private let headH: CGFloat = 20
    private let cardPad: CGFloat = 12
    private let cardGap: CGFloat = 10
    private let outerTitleH: CGFloat = 46

    private func moduleHeight(_ m: PanelModule) -> CGFloat {
        let pad = cardPad * 2
        switch m {
        case .keys(_, let rows, _):
            return headH + CGFloat(rows.count) * 23 + pad
        case .donuts(_, let items):
            let rows = Int(ceil(Double(items.count) / 2.0))
            return headH + CGFloat(rows) * 88 + CGFloat(max(0, rows - 1)) * 10 + pad
        case .gauges(_, let items):
            return headH + CGFloat(items.count) * 24 + pad
        case .sparks(_, let items):
            return headH + CGFloat(items.count) * 72 + pad
        case .convo:
            return headH + CGFloat(min(max(convo.count, 1), 6)) * 19 + pad
        case .log:
            return headH + CGFloat(min(max(log.count, 1), 10)) * 18 + pad
        }
    }

    private func attrs(_ color: NSColor, _ size: CGFloat, _ weight: NSFont.Weight = .regular) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.monospacedSystemFont(ofSize: size, weight: weight),
         .foregroundColor: color]
    }

    override func draw(_ dirtyRect: NSRect) {
        drawOuterTitle()
        let contentTop = bounds.height - outerTitleH - 6
        let totalH = modules.reduce(CGFloat(0)) { $0 + moduleHeight($1) + cardGap } - cardGap
        let scale = min(1.0, contentTop / max(totalH, 1))
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        ctx.translateBy(x: 0, y: contentTop - totalH * scale)
        ctx.scaleBy(x: scale, y: scale)

        var y = totalH
        for m in modules {
            let h = moduleHeight(m)
            drawCard(m, top: y, height: h)
            y -= h + cardGap
        }
        ctx.restoreGState()
    }

    private func drawOuterTitle() {
        let top = bounds.height - outerTitleH + 18
        let attrs = attrs(NSColor(calibratedRed: 0.55, green: 0.92, blue: 1.0, alpha: 0.95), 13, .bold)
        (title as NSString).draw(at: NSPoint(x: 16, y: top), withAttributes: attrs)
        let sep = NSBezierPath()
        sep.move(to: NSPoint(x: 14, y: top - 20))
        sep.line(to: NSPoint(x: bounds.width - 14, y: top - 20))
        NSColor(calibratedRed: 0.3, green: 0.8, blue: 1.0, alpha: 0.3).setStroke()
        sep.lineWidth = 1
        sep.stroke()
    }

    private func moduleTitle(_ m: PanelModule) -> String {
        switch m {
        case .keys(let t, _, _): return t
        case .donuts(let t, _): return t
        case .gauges(let t, _): return t
        case .sparks(let t, _): return t
        case .convo(let t, _): return t
        case .log(let t, _): return t
        }
    }

    private func moduleAccent(_ m: PanelModule) -> NSColor {
        switch m {
        case .keys(_, _, let c): return c
        case .donuts(_, let items): return items.first.map { $0.2 } ?? PALETTE[0]
        case .gauges(_, let items): return items.first.map { $0.2 } ?? PALETTE[0]
        case .sparks(_, let items): return items.first.map { $0.2 } ?? PALETTE[0]
        case .convo(_, let c): return c
        case .log(_, let c): return c
        }
    }

    private func drawCard(_ m: PanelModule, top: CGFloat, height: CGFloat) {
        let rect = NSRect(x: 3, y: top - height + 4, width: bounds.width - 6, height: height - 4)
        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        NSColor(calibratedWhite: 0.03, alpha: 0.60).setFill()
        path.fill()
        let accent = moduleAccent(m)
        for (w, a) in [(4.0, 0.12), (1.0, 0.6)] {
            accent.withAlphaComponent(a).setStroke()
            path.lineWidth = w
            path.stroke()
        }

        let titleY = rect.maxY - headH - 4
        let dot = NSBezierPath(ovalIn: NSRect(x: rect.minX + 10, y: titleY + 5, width: 6, height: 6))
        accent.setFill()
        dot.fill()
        let titleColor = accent.blended(withFraction: 0.55, of: .white) ?? accent
        (moduleTitle(m) as NSString).draw(at: NSPoint(x: rect.minX + 22, y: titleY + 2),
                                          withAttributes: attrs(titleColor, 11.5, .bold))
        let sep = NSBezierPath()
        sep.move(to: NSPoint(x: rect.minX + 10, y: titleY - 5))
        sep.line(to: NSPoint(x: rect.maxX - 10, y: titleY - 5))
        accent.withAlphaComponent(0.28).setStroke()
        sep.lineWidth = 0.5
        sep.stroke()

        switch m {
        case .keys(_, let rows, let color):
            drawKeys(rows, color: color, in: rect, below: titleY)
        case .donuts(_, let items):
            drawDonuts(items, in: rect, below: titleY)
        case .gauges(_, let items):
            drawGauges(items, in: rect, below: titleY)
        case .sparks(_, let items):
            drawSparks(items, in: rect, below: titleY)
        case .convo:
            drawConvo(in: rect, below: titleY)
        case .log:
            drawLog(in: rect, below: titleY)
        }
    }

    private func drawKeys(_ rows: [(String, String)], color: NSColor, in rect: NSRect, below titleY: CGFloat) {
        let labelColor = color.blended(withFraction: 0.35, of: .white) ?? color
        let valueColor = NSColor(calibratedRed: 0.82, green: 0.97, blue: 1.0, alpha: 1)
        var y = titleY - 14
        for (label, key) in rows {
            (label as NSString).draw(at: NSPoint(x: rect.minX + 16, y: y), withAttributes: attrs(labelColor, 12))
            (truncate(info[key] ?? "—", 24) as NSString).draw(at: NSPoint(x: rect.minX + 92, y: y), withAttributes: attrs(valueColor, 12))
            y -= 23
        }
    }

    private func drawDonuts(_ items: [(String, String, NSColor)], in rect: NSRect, below titleY: CGFloat) {
        let d: CGFloat = 74
        let gap: CGFloat = 16
        let perRow = 2
        let totalW = CGFloat(perRow) * d + CGFloat(perRow - 1) * gap
        for (i, item) in items.enumerated() {
            let col = i % perRow
            let row = i / perRow
            let cx = rect.midX - totalW / 2 + CGFloat(col) * (d + gap) + d / 2
            let cy = titleY - 22 - CGFloat(row) * (d + 16) - d / 2
            drawDonut(item.0, key: item.1, color: item.2, cx: cx, cy: cy, d: d)
        }
    }

    private func drawDonut(_ label: String, key: String, color: NSColor, cx: CGFloat, cy: CGFloat, d: CGFloat) {
        let pct = min(100, max(0, CGFloat(Double(info[key] ?? "0") ?? 0))) / 100
        let r = d / 2 - 8
        let lineW: CGFloat = 10
        let center = NSPoint(x: cx, y: cy)

        let bgRing = NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        NSColor(calibratedWhite: 0.13, alpha: 0.5).setStroke()
        bgRing.lineWidth = lineW
        bgRing.stroke()

        let glow = NSBezierPath()
        glow.appendArc(withCenter: center, radius: r, startAngle: -90, endAngle: -90 + 360 * pct, clockwise: false)
        color.withAlphaComponent(0.22).setStroke()
        glow.lineWidth = lineW + 7
        glow.lineCapStyle = .round
        glow.stroke()

        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: r, startAngle: -90, endAngle: -90 + 360 * pct, clockwise: false)
        color.setStroke()
        arc.lineWidth = lineW
        arc.lineCapStyle = .round
        arc.stroke()

        let pctText = String(format: "%.0f%%", pct * 100) as NSString
        let pctColor = color.blended(withFraction: 0.5, of: .white) ?? color
        let pctAttrs = attrs(pctColor, 14, .bold)
        let pctSize = pctText.size(withAttributes: pctAttrs)
        pctText.draw(at: NSPoint(x: cx - pctSize.width / 2, y: cy - pctSize.height / 2), withAttributes: pctAttrs)

        let nameAttrs = attrs(NSColor(calibratedRed: 0.6, green: 0.9, blue: 1.0, alpha: 0.9), 10.5)
        let nameSize = (label as NSString).size(withAttributes: nameAttrs)
        (label as NSString).draw(at: NSPoint(x: cx - nameSize.width / 2, y: cy - d / 2 - 8), withAttributes: nameAttrs)
    }

    private func drawGauges(_ items: [(String, String, NSColor)], in rect: NSRect, below titleY: CGFloat) {
        var y = titleY - 14
        for (label, key, color) in items {
            drawGauge(label: label, key: key, color: color, at: NSPoint(x: rect.minX + 16, y: y), maxX: rect.maxX)
            y -= 24
        }
    }

    private func drawGauge(label: String, key: String, color: NSColor, at origin: NSPoint, maxX: CGFloat) {
        let pct = min(100, max(0, CGFloat(Double(info[key] ?? "0") ?? 0)))
        let barH: CGFloat = 10
        let barX = origin.x + 62
        let barW = maxX - barX - 56
        let barY = origin.y + 1
        (label as NSString).draw(at: origin, withAttributes: attrs(NSColor(calibratedRed: 0.5, green: 0.82, blue: 0.95, alpha: 0.9), 12))

        let bg = NSBezierPath(roundedRect: NSRect(x: barX, y: barY, width: barW, height: barH), xRadius: 5, yRadius: 5)
        NSColor(calibratedWhite: 0.16, alpha: 0.55).setFill()
        bg.fill()

        if pct > 0.5 {
            let fill = NSBezierPath(roundedRect: NSRect(x: barX, y: barY, width: max(4, barW * pct / 100), height: barH), xRadius: 5, yRadius: 5)
            let fillColor = color.blended(withFraction: 0.5, of: .white) ?? color
            let gradient = NSGradient(colors: [color.withAlphaComponent(0.85), fillColor.withAlphaComponent(0.95)])!
            gradient.draw(in: fill, angle: 0)
        }
        let pctText = String(format: "%.0f%%", pct) as NSString
        (pctText as NSString).draw(at: NSPoint(x: barX + barW + 6, y: origin.y + 1),
                                   withAttributes: attrs(NSColor(calibratedRed: 0.82, green: 0.97, blue: 1.0, alpha: 1), 12))
    }

    private func drawSparks(_ items: [(String, String, NSColor)], in rect: NSRect, below titleY: CGFloat) {
        var y = titleY - 16
        for (label, key, color) in items {
            drawSpark(label: label, key: key, color: color, in: rect, at: y)
            y -= 72
        }
    }

    private func drawSpark(label: String, key: String, color: NSColor, in rect: NSRect, at y: CGFloat) {
        let values = numbers(from: info[key] ?? "")
        let chartH: CGFloat = 46
        let chartY = y - chartH
        (label as NSString).draw(at: NSPoint(x: rect.minX + 16, y: y - 12),
                                 withAttributes: attrs(NSColor(calibratedRed: 0.5, green: 0.82, blue: 0.95, alpha: 0.85), 11))
        guard values.count > 1 else { return }

        let chartX = rect.minX + 14
        let chartW = rect.width - 28
        let lo = values.min() ?? 0
        let hi = max(values.max() ?? 1, lo + 0.001)
        let span = hi - lo
        let pts: [NSPoint] = values.enumerated().map { i, v in
            NSPoint(x: chartX + CGFloat(i) / CGFloat(values.count - 1) * chartW,
                    y: chartY + (v - lo) / span * (chartH - 8) + 4)
        }

        for g in 0...2 {
            let gy = chartY + CGFloat(g) / 2 * (chartH - 8) + 4
            let grid = NSBezierPath()
            grid.move(to: NSPoint(x: chartX, y: gy))
            grid.line(to: NSPoint(x: chartX + chartW, y: gy))
            color.withAlphaComponent(0.10).setStroke()
            grid.lineWidth = 0.5
            grid.stroke()
        }

        let area = NSBezierPath()
        area.move(to: pts[0])
        for p in pts.dropFirst() { area.line(to: p) }
        area.line(to: NSPoint(x: pts.last!.x, y: chartY))
        area.line(to: NSPoint(x: pts[0].x, y: chartY))
        area.close()
        color.withAlphaComponent(0.10).setFill()
        area.fill()

        let line = NSBezierPath()
        line.move(to: pts[0])
        for p in pts.dropFirst() { line.line(to: p) }
        color.withAlphaComponent(0.30).setStroke()
        line.lineWidth = 4
        line.stroke()
        let lineColor = color.blended(withFraction: 0.55, of: .white) ?? color
        lineColor.setStroke()
        line.lineWidth = 1.5
        line.stroke()

        if let last = pts.last {
            let dot = NSBezierPath(ovalIn: NSRect(x: last.x - 2.5, y: last.y - 2.5, width: 5, height: 5))
            NSColor.white.withAlphaComponent(0.9).setFill()
            dot.fill()
        }
    }

    private func drawConvo(in rect: NSRect, below titleY: CGFloat) {
        var y = titleY - 16
        for line in Array(convo.suffix(6)) {
            let isJarvis = line.hasPrefix("Jarvis:")
            let color = isJarvis
                ? NSColor(calibratedRed: 0.65, green: 0.95, blue: 1.0, alpha: 0.95)
                : NSColor(calibratedRed: 0.55, green: 0.85, blue: 0.95, alpha: 0.8)
            (truncate(line, 38) as NSString).draw(at: NSPoint(x: rect.minX + 16, y: y), withAttributes: attrs(color, 11))
            y -= 19
        }
    }

    private func drawLog(in rect: NSRect, below titleY: CGFloat) {
        var y = titleY - 16
        for line in Array(log.suffix(10)) {
            (truncate(line, 38) as NSString).draw(at: NSPoint(x: rect.minX + 16, y: y),
                                                  withAttributes: attrs(NSColor(calibratedRed: 0.55, green: 0.88, blue: 1.0, alpha: 0.85), 11))
            y -= 18
        }
    }

    private func numbers(from raw: String) -> [CGFloat] {
        raw.split(separator: ",").compactMap { CGFloat(Double($0.trimmingCharacters(in: .whitespaces)) ?? 0) }
    }

    private func truncate(_ text: String, _ limit: Int) -> String {
        if text.count <= limit {
            return text
        }
        return String(text.prefix(limit)) + "…"
    }
}


// ---------- 主入口 ----------
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let avatarView = AvatarView(frame: NSRect(x: 0, y: 0, width: 460, height: 460))
if let idx = CommandLine.arguments.firstIndex(of: "--mode"), idx + 1 < CommandLine.arguments.count {
    avatarView.mode = CommandLine.arguments[idx + 1]
}

let avatarWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 460),
                            styleMask: [.borderless], backing: .buffered, defer: false)
avatarWindow.isOpaque = false
avatarWindow.backgroundColor = .clear
avatarWindow.hasShadow = false
avatarWindow.level = .floating
avatarWindow.isMovableByWindowBackground = true
avatarWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
avatarWindow.contentView = avatarView
avatarWindow.center()
avatarWindow.orderFrontRegardless()

// 左侧环境信息面板（底部到顶部）
func panelRect(width: CGFloat, left: Bool) -> NSRect {
    if let screen = NSScreen.main?.visibleFrame {
        let h = screen.height - 48
        let x = left ? screen.minX + 20 : screen.maxX - 20 - width
        return NSRect(x: x, y: screen.minY + 24, width: width, height: h)
    }
    return NSRect(x: left ? 24 : 0, y: 24, width: width, height: 700)
}

let panelW: CGFloat = 340
let leftPanel = PanelView(frame: NSRect(x: 0, y: 0, width: panelW, height: 700))
leftPanel.title = "JARVIS // 环境信息"
leftPanel.modules = [
    .keys(title: "基础信息", rows: [
        ("时间", "time"), ("日期", "date"), ("天气", "weather"), ("负载", "load"), ("网络", "net"),
    ], color: PALETTE[0]),
    .donuts(title: "资源占用", items: [
        ("CPU", "load_pct", PALETTE[1]),
        ("内存", "mem_pct", PALETTE[0]),
        ("磁盘", "disk_pct", PALETTE[3]),
        ("电池", "batt_pct", PALETTE[2]),
    ]),
    .sparks(title: "负载与网络趋势", items: [
        ("负载", "load_hist", PALETTE[3]),
        ("网络延迟", "net_hist", PALETTE[1]),
    ]),
    .keys(title: "系统概况", rows: [
        ("IP", "ip"), ("运行", "uptime"), ("进程", "processes"), ("内核", "kernel"),
    ], color: PALETTE[2]),
]
let leftWindow = NSWindow(contentRect: panelRect(width: panelW, left: true),
                          styleMask: [.borderless], backing: .buffered, defer: false)
leftWindow.isOpaque = false
leftWindow.backgroundColor = .clear
leftWindow.hasShadow = false
leftWindow.level = .floating
leftWindow.isMovableByWindowBackground = true
leftWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
leftWindow.contentView = leftPanel
leftWindow.orderFrontRegardless()

// 右侧系统状态面板（底部到顶部）
let rightPanel = PanelView(frame: NSRect(x: 0, y: 0, width: panelW, height: 700))
rightPanel.title = "JARVIS // 系统状态"
rightPanel.modules = [
    .keys(title: "核心状态", rows: [
        ("状态", "status"), ("模型", "model"), ("延迟", "latency"), ("会话", "session"),
    ], color: PALETTE[2]),
    .convo(title: "实时对话", color: PALETTE[0]),
    .sparks(title: "接口与电量趋势", items: [
        ("接口延迟", "latency_hist", PALETTE[4]),
        ("电量趋势", "batt_hist", PALETTE[1]),
    ]),
    .log(title: "活动日志", color: PALETTE[5]),
]
let rightWindow = NSWindow(contentRect: panelRect(width: panelW, left: false),
                           styleMask: [.borderless], backing: .buffered, defer: false)
rightWindow.isOpaque = false
rightWindow.backgroundColor = .clear
rightWindow.hasShadow = false
rightWindow.level = .floating
rightWindow.isMovableByWindowBackground = true
rightWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
rightWindow.contentView = rightPanel
rightWindow.orderFrontRegardless()

// 30fps 动画刷新
let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { _ in
    avatarView.needsDisplay = true
    leftPanel.needsDisplay = true
    rightPanel.needsDisplay = true
}
RunLoop.main.add(timer, forMode: .common)

// stdin 控制
FileHandle.standardInput.readabilityHandler = { handle in
    let data = handle.availableData
    if data.isEmpty {
        exit(0)
    }
    guard let input = String(data: data, encoding: .utf8) else { return }
    for raw in input.split(separator: "\n") {
        let command = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async {
            switch command {
            case "idle", "listen", "speak":
                avatarView.mode = command
            case "show":
                avatarWindow.orderFrontRegardless()
                leftWindow.orderFrontRegardless()
                rightWindow.orderFrontRegardless()
            case "hide":
                avatarWindow.orderOut(nil)
                leftWindow.orderOut(nil)
                rightWindow.orderOut(nil)
            case "center":
                avatarWindow.center()
            case "quit":
                exit(0)
            default:
                if command.hasPrefix("info:") {
                    let json = String(command.dropFirst(5))
                    if let data = json.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                        leftPanel.info = obj
                        rightPanel.info = obj
                        rightPanel.log = (obj["log"] ?? "").split(separator: "\n").map(String.init)
                        rightPanel.convo = (obj["convo"] ?? "").split(separator: "\n").map(String.init)
                    }
                }
            }
        }
    }
}

app.run()
