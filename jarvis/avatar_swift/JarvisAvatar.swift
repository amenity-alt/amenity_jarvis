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
