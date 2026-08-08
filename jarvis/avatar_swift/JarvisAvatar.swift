// JarvisAvatar.swift — 钢铁侠风格 JARVIS 全息头像（浮动窗口，无边框）
// 用法: JarvisAvatar [--mode idle|listen|speak]
// 运行期间可通过 stdin 发送命令：idle / listen / speak / show / hide / center / quit

import AppKit

final class AvatarView: NSView {
    var mode = "idle"

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let now = Date().timeIntervalSinceReferenceDate
        let w = bounds.width
        let h = bounds.height
        let cx = w / 2
        let cy = h / 2
        let base = min(w, h)

        // 背景：半透明深色圆盘
        let bg = NSBezierPath(ovalIn: NSRect(x: cx - base * 0.46, y: cy - base * 0.46,
                                             width: base * 0.92, height: base * 0.92))
        NSColor(calibratedWhite: 0.04, alpha: 0.60).setFill()
        bg.fill()

        // 旋转分段光环（Arc Reactor 效果）
        let ringRadius = base * 0.40
        let segmentCount = 40
        let segment = CGFloat.pi * 2 / CGFloat(segmentCount)
        let rotation = CGFloat(now.truncatingRemainder(dividingBy: 5.0) / 5.0) * .pi * 2
        for i in 0..<segmentCount {
            let start = CGFloat(i) * segment + rotation
            let glow = CGFloat(0.15 + 0.85 * abs(sin(Double(i) * 0.37 + now * 2.2)))
            NSColor(calibratedRed: 0.25, green: 0.82, blue: 1.0, alpha: glow).setStroke()
            let path = NSBezierPath()
            path.lineWidth = base * 0.014
            path.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: ringRadius,
                           startAngle: start * 180 / .pi, endAngle: (start + segment * 0.65) * 180 / .pi,
                           clockwise: false)
            path.stroke()
        }

        // 内环
        let innerRing = NSBezierPath(ovalIn: NSRect(x: cx - base * 0.26, y: cy - base * 0.26,
                                                    width: base * 0.52, height: base * 0.52))
        NSColor(calibratedRed: 0.3, green: 0.85, blue: 1.0, alpha: 0.45).setStroke()
        innerRing.lineWidth = base * 0.006
        innerRing.stroke()

        // 模式效果
        if mode == "listen" {
            drawWaveform(cx: cx, cy: cy, base: base, now: now)
        } else if mode == "speak" {
            drawRipples(cx: cx, cy: cy, base: base, now: now)
        }

        // 中心核心（脉冲）
        let pulse = CGFloat(0.8 + 0.2 * sin(now * 3))
        let coreRadius = base * 0.11 * pulse
        let coreRect = NSRect(x: cx - coreRadius, y: cy - coreRadius,
                              width: coreRadius * 2, height: coreRadius * 2)
        let core = NSBezierPath(ovalIn: coreRect)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.9, green: 0.98, blue: 1.0, alpha: 1),
            NSColor(calibratedRed: 0.15, green: 0.58, blue: 0.95, alpha: 1),
        ])!
        gradient.draw(in: core, angle: -90)

        // JARVIS 文字（发光）
        drawLabel(cx: cx, cy: cy, base: base)
    }

    private func drawWaveform(cx: CGFloat, cy: CGFloat, base: CGFloat, now: TimeInterval) {
        let barCount = 26
        let barWidth = base * 0.016
        for i in 0..<barCount {
            let wave = CGFloat(0.5 + 0.5 * sin(Double(i) * 1.9 + now * 9))
            let height = base * (0.05 + 0.16 * wave)
            let angle = CGFloat(Double(i) / Double(barCount) * Double.pi * 2)
            let radius = base * 0.21
            let x0 = cx + CGFloat(cos(angle)) * radius
            let y0 = cy + CGFloat(sin(angle)) * radius
            let rect = NSRect(x: x0 - barWidth / 2, y: y0, width: barWidth, height: height)
            NSColor(calibratedRed: 0.3, green: 0.85, blue: 1.0, alpha: 0.9).setFill()
            NSBezierPath(rect: rect).fill()
        }
    }

    private func drawRipples(cx: CGFloat, cy: CGFloat, base: CGFloat, now: TimeInterval) {
        for i in 0..<3 {
            let t = (now * 0.9 + Double(i) / 3).truncatingRemainder(dividingBy: 1.0)
            let radius = base * CGFloat(0.12 + 0.28 * t)
            let alpha = CGFloat(1.0 - t)
            let path = NSBezierPath(ovalIn: NSRect(x: cx - radius, y: cy - radius,
                                                   width: radius * 2, height: radius * 2))
            NSColor(calibratedRed: 0.3, green: 0.85, blue: 1.0, alpha: alpha * 0.55).setStroke()
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
        let origin = NSPoint(x: cx - size.width / 2, y: cy - base * 0.36)
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

// ---------- 主入口 ----------
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let view = AvatarView(frame: NSRect(x: 0, y: 0, width: 420, height: 420))
if let idx = CommandLine.arguments.firstIndex(of: "--mode"), idx + 1 < CommandLine.arguments.count {
    view.mode = CommandLine.arguments[idx + 1]
}

let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
                      styleMask: [.borderless], backing: .buffered, defer: false)
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = false
window.level = .floating
window.isMovableByWindowBackground = true
window.collectionBehavior = [.canJoinAllSpaces, .stationary]
window.contentView = view
window.center()
window.orderFrontRegardless()

// 30fps 动画刷新
let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { _ in
    view.needsDisplay = true
}
RunLoop.main.add(timer, forMode: .common)

// stdin 控制：idle / listen / speak / show / hide / center / quit
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
                view.mode = command
            case "show":
                window.orderFrontRegardless()
            case "hide":
                window.orderOut(nil)
            case "center":
                window.center()
            case "quit":
                exit(0)
            default:
                break
            }
        }
    }
}

app.run()
