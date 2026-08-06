import AppKit

enum SpotifyMenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.labelColor.setStroke()

            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
            circle.lineWidth = 1.5
            circle.stroke()

            for index in 0..<3 {
                let offset = CGFloat(index) * 3
                let path = NSBezierPath()
                path.move(to: NSPoint(x: 4.2, y: 11.7 - offset))
                path.curve(
                    to: NSPoint(x: 13.8, y: 10.8 - offset),
                    controlPoint1: NSPoint(x: 7.4, y: 13.0 - offset),
                    controlPoint2: NSPoint(x: 11.2, y: 12.6 - offset)
                )
                path.lineWidth = index == 0 ? 1.5 : 1.25
                path.lineCapStyle = .round
                path.stroke()
            }

            return true
        }
        image.isTemplate = true
        return image
    }()
}
