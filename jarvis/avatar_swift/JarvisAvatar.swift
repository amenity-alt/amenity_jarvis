// JarvisAvatar.swift — 钢铁侠风格 JARVIS 全息头像（光点粒子 → 钢铁侠面具形态）+ 环境信息面板
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
    private var showHelmet = false
    private var lastTime: TimeInterval = 0

    // 粒子数量
    private let OUTLINE = 120
    private let EYES = 80
    private let BROWS = 32
    private let NOSE = 16
    private let MOUTH = 32
    private let PUPILS = 64
    private let HALO = 48
    private let DUST = 28
    private var totalCount: Int { OUTLINE + EYES + BROWS + NOSE + MOUTH + PUPILS + HALO + DUST }

    // 钢铁侠头盔轮廓顶点（单位坐标，x 对称）：宽颊、棱角、尖下巴
    private let helmetVerts: [(CGFloat, CGFloat)] = [
        (0.00, 0.48), (0.14, 0.47), (0.24, 0.44), (0.30, 0.38), (0.34, 0.28),
        (0.38, 0.16), (0.40, 0.02), (0.36, -0.10), (0.28, -0.22), (0.18, -0.33),
        (0.08, -0.41), (0.00, -0.44),
    ]

    override var isOpaque: Bool { false }

    private func smoothstep(_ p: CGFloat) -> CGFloat {
        let t = max(0, min(1, p))
        return t * t * (3 - 2 * t)
    }

    // 沿多边形周长均匀取点（单位坐标）
    private func polygonPoints(_ verts: [(CGFloat, CGFloat)], count: Int) -> [(CGFloat, CGFloat)] {
        var segs: [(CGFloat, CGFloat, CGFloat, CGFloat)] = []
        var total: CGFloat = 0
        for k in 0..<verts.count {
            let a = verts[k]
            let b = verts[(k + 1) % verts.count]
            let len = hypot(b.0 - a.0, b.1 - a.1)
            segs.append((a.0, a.1, b.0, b.1))
            total += len
        }
        var out: [(CGFloat, CGFloat)] = []
        for s in segs {
            let len = hypot(s.2 - s.0, s.3 - s.1)
            let n = max(1, Int(round(len / total * CGFloat(count))))
            for j in 0..<n {
                if out.count >= count { break }
                let t = CGFloat(j) / CGFloat(n)
                out.append((s.0 + (s.2 - s.0) * t, s.1 + (s.3 - s.1) * t))
            }
        }
        while out.count < count {
            out.append(out.last ?? (0, 0))
        }
        return out
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
            showHelmet = false
        }
        let w = bounds.width
        let h = bounds.height
        let cx = w / 2
        let cy = h / 2
        let base = min(w, h)
        let rotation = CGFloat(now.truncatingRemainder(dividingBy: 6.0) / 6.0) * .pi * 2
        let pulse = CGFloat(0.85 + 0.15 * sin(now * 3.2))
        if progress >= 1 {
            showHelmet = true
        }

        for (index, particle) in particles.enumerated() {
            var tx = cx
            var ty = cy
            var driftX: CGFloat = 0
            var driftY: CGFloat = 0
            if showHelmet {
                (tx, ty, driftX, driftY) = helmetTarget(index, cx: cx, cy: cy, base: base,
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
        let ringEnd = 200
        let innerEnd = 248
        let coreEnd = 280
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

    // 钢铁侠面具形态（组装完成后变身）
    private func helmetTarget(_ i: Int, cx: CGFloat, cy: CGFloat, base: CGFloat,
                              now: TimeInterval, rotation: CGFloat, phase: Double) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        let outlineEnd = OUTLINE
        let eyesEnd = outlineEnd + EYES
        let browsEnd = eyesEnd + BROWS
        let noseEnd = browsEnd + NOSE
        let mouthEnd = noseEnd + MOUTH
        let pupilsEnd = mouthEnd + PUPILS
        let haloEnd = pupilsEnd + HALO

        let breathe = CGFloat(1 + 0.010 * sin(now * 1.6))
        var tx = cx
        var ty = cy
        var dx: CGFloat = 0
        var dy: CGFloat = 0

        if i < outlineEnd {
            // 头盔轮廓：沿多边形取点
            var verts = helmetVerts
            for v in helmetVerts.dropFirst().dropLast().reversed() {
                verts.append((-v.0, v.1))
            }
            let pts = polygonPoints(verts, count: OUTLINE)
            let p = pts[i]
            tx = cx + p.0 * base * breathe
            ty = cy + p.1 * base * breathe
        } else if i < eyesEnd {
            // 发光斜眼（左右各 40 点：2 行 × 20）
            let j = i - outlineEnd
            let side: CGFloat = j < EYES / 2 ? -1 : 1
            let k = j % (EYES / 2)
            let row = k < 20 ? 0.0 : 0.014
            let t = CGFloat(k % 20) / 19
            let ex = (side < 0 ? -0.17 + 0.11 * t : 0.06 + 0.11 * t)
            let ey = 0.10 + 0.035 * t + row
            tx = cx + ex * base
            ty = cy + ey * base
            dy = CGFloat(sin(now * 2 + Double(k))) * base * 0.003
        } else if i < browsEnd {
            // 眉脊（左右各 16 点：2 行 × 8，V 形下压）
            let j = i - eyesEnd
            let side: CGFloat = j < BROWS / 2 ? -1 : 1
            let k = j % (BROWS / 2)
            let row = k < 8 ? 0.0 : 0.014
            let t = CGFloat(k % 8) / 7
            let bx = side < 0 ? -0.20 + 0.14 * t : 0.06 + 0.14 * t
            let by = 0.175 - 0.045 * t + row
            tx = cx + bx * base
            ty = cy + by * base
        } else if i < noseEnd {
            // 鼻梁（16 点：2 列 × 8）
            let j = i - browsEnd
            let col: CGFloat = j < NOSE / 2 ? -0.012 : 0.012
            let t = CGFloat(j % (NOSE / 2)) / 7
            tx = cx + col * base
            ty = cy + (0.07 - t * 0.09) * base
        } else if i < mouthEnd {
            // 嘴部格栅（4 条竖杠 × 8 点）
            let j = i - noseEnd
            let bar = j / 8
            let bars: [CGFloat] = [-0.10, -0.033, 0.033, 0.10]
            let t = CGFloat(j % 8) / 7
            let mx = bars[bar]
            var my = -0.13 - t * 0.045
            if mode == "speak" {
                my -= abs(sin(now * 16)) * 0.03
            } else if mode == "listen" {
                my -= sin(now * 6) * 0.006
            }
            tx = cx + mx * base
            ty = cy + my * base
        } else if i < pupilsEnd {
            // 发光眼核（左右各 32 点）
            let j = i - mouthEnd
            let side: CGFloat = j < PUPILS / 2 ? -1 : 1
            let k = j % (PUPILS / 2)
            let a = CGFloat(Double(k) / Double(PUPILS / 2) * Double.pi * 2)
            let r = base * 0.030 * (1 + 0.2 * sin(now * 2.4 + Double(k)))
            tx = cx + side * base * 0.115 + cos(a) * r
            ty = cy + base * 0.125 + sin(a) * r * 0.7
        } else if i < haloEnd {
            // 面具外圈光晕（48 点，缓慢旋转）
            let j = i - pupilsEnd
            let a = -CGFloat.pi / 2 + CGFloat(Double(j) / Double(HALO) * Double.pi * 2) + rotation * 0.3
            let r = base * (0.56 + 0.02 * sin(now * 1.1 + Double(j)))
            tx = cx + cos(a) * r
            ty = cy + sin(a) * r * 1.05
        } else {
            // 漂浮光尘
            let j = i - haloEnd
            let speed = 0.3 + 0.1 * Double(j % 3)
            tx = cx + CGFloat(sin(now * speed + phase)) * base * 0.66
            ty = cy + CGFloat(cos(now * speed * 0.83 + phase * 1.3)) * base * 0.66
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
        let eyesEnd = OUTLINE + EYES
        let mouthEnd = eyesEnd + BROWS + NOSE + MOUTH
        let pupilsEnd = mouthEnd + PUPILS
        let haloEnd = pupilsEnd + HALO
        for (index, p) in particles.enumerated() {
            if showHelmet && index >= eyesEnd && index < pupilsEnd {
                // 眼睛（轮廓+眼核）：亮白发光
                let glow = p.size * 4.5
                NSColor(calibratedRed: 0.55, green: 0.92, blue: 1.0, alpha: 0.25).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - glow / 2, y: p.y - glow / 2,
                                            width: glow, height: glow)).fill()
                let bright: CGFloat = index < mouthEnd ? 0.95 : 1.0
                NSColor(calibratedRed: bright, green: 0.99, blue: 1.0, alpha: 1).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - p.size * 0.85, y: p.y - p.size * 0.85,
                                            width: p.size * 1.7, height: p.size * 1.7)).fill()
            } else if showHelmet && index >= haloEnd - HALO && index < haloEnd {
                // 外圈光晕：淡一些
                NSColor(calibratedRed: 0.3, green: 0.8, blue: 1.0, alpha: 0.4).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - p.size * 0.5, y: p.y - p.size * 0.5,
                                            width: p.size, height: p.size)).fill()
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
        let font = NSFont(name: "Avenir Next Heavy", size: base * 0.095)
            ?? NSFont.systemFont(ofSize: base * 0.095, weight: .heavy)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedRed: 0.55, green: 0.92, blue: 1.0, alpha: 0.95),
            .kern: base * 0.03,
        ]
        let size = text.size(withAttributes: attrs)
        let labelY = showHelmet ? cy - base * 0.46 : cy - base * 0.36
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

// ---------- 环境信息面板 ----------
final class PanelView: NSView {
    var info: [String: String] = [:]

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let bg = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
        NSColor(calibratedWhite: 0.02, alpha: 0.62).setFill()
        bg.fill()
        NSColor(calibratedRed: 0.25, green: 0.8, blue: 1.0, alpha: 0.35).setStroke()
        bg.lineWidth = 1
        bg.stroke()

        let title = "JARVIS // 环境信息" as NSString
        let titleFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        title.draw(at: NSPoint(x: 16, y: bounds.height - 30), withAttributes: [
            .font: titleFont,
            .foregroundColor: NSColor(calibratedRed: 0.5, green: 0.9, blue: 1.0, alpha: 0.9),
        ])

        let sep = NSBezierPath()
        sep.move(to: NSPoint(x: 14, y: bounds.height - 40))
        sep.line(to: NSPoint(x: bounds.width - 14, y: bounds.height - 40))
        NSColor(calibratedRed: 0.3, green: 0.8, blue: 1.0, alpha: 0.25).setStroke()
        sep.lineWidth = 0.5
        sep.stroke()

        let rowFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: rowFont,
            .foregroundColor: NSColor(calibratedRed: 0.35, green: 0.75, blue: 0.95, alpha: 0.9),
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: rowFont,
            .foregroundColor: NSColor(calibratedRed: 0.7, green: 0.95, blue: 1.0, alpha: 1),
        ]
        let rows: [(String, String)] = [
            ("时间", info["time"] ?? "--:--:--"),
            ("日期", info["date"] ?? "----"),
            ("天气", truncate(info["weather"] ?? "获取中…", 26)),
            ("电池", info["battery"] ?? "未知"),
            ("负载", info["load"] ?? "未知"),
            ("内存", info["mem"] ?? "未知"),
            ("网络", info["net"] ?? "检测中"),
        ]
        var y = bounds.height - 62
        for (label, value) in rows {
            (label as NSString).draw(at: NSPoint(x: 16, y: y), withAttributes: labelAttrs)
            (value as NSString).draw(at: NSPoint(x: 76, y: y), withAttributes: valueAttrs)
            y -= 24
        }
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

// 左下角环境信息面板
let panelView = PanelView(frame: NSRect(x: 0, y: 0, width: 340, height: 232))
let panelWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 232),
                           styleMask: [.borderless], backing: .buffered, defer: false)
panelWindow.isOpaque = false
panelWindow.backgroundColor = .clear
panelWindow.hasShadow = false
panelWindow.level = .floating
panelWindow.isMovableByWindowBackground = true
panelWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
panelWindow.contentView = panelView
if let screen = NSScreen.main?.visibleFrame {
    panelWindow.setFrameOrigin(NSPoint(x: screen.minX + 24, y: screen.minY + 24))
}
panelWindow.orderFrontRegardless()

// 30fps 动画刷新
let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { _ in
    avatarView.needsDisplay = true
    panelView.needsDisplay = true
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
                panelWindow.orderFrontRegardless()
            case "hide":
                avatarWindow.orderOut(nil)
                panelWindow.orderOut(nil)
            case "center":
                avatarWindow.center()
            case "quit":
                exit(0)
            default:
                if command.hasPrefix("info:") {
                    let json = String(command.dropFirst(5))
                    if let data = json.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                        panelView.info = obj
                    }
                }
            }
        }
    }
}

app.run()
