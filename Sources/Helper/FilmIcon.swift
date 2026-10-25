import AppKit

/// 메뉴 막대용 필름 통 아이콘. 템플릿 이미지라 밝은/어두운 메뉴 막대에 맞춰 색이 바뀐다.
enum FilmIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 16), flipped: false) { _ in
            NSColor.black.setFill()

            // 필름 통: 아래 뚜껑, 몸통, 위 뚜껑, 심
            NSBezierPath(roundedRect: NSRect(x: 0, y: 0.5, width: 9, height: 2), xRadius: 0.8, yRadius: 0.8).fill()
            NSBezierPath(rect: NSRect(x: 1, y: 2, width: 7, height: 11)).fill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 12.5, width: 9, height: 2), xRadius: 0.8, yRadius: 0.8).fill()
            NSBezierPath(rect: NSRect(x: 3, y: 14.3, width: 3, height: 1.5)).fill()

            // 빠져나온 필름: 끝이 반쯤 잘린 모양에 구멍을 뚫는다.
            let film = NSBezierPath()
            film.move(to: NSPoint(x: 9, y: 4))
            film.line(to: NSPoint(x: 13, y: 4))
            film.curve(to: NSPoint(x: 15, y: 7.5), controlPoint1: NSPoint(x: 14.3, y: 4), controlPoint2: NSPoint(x: 14.2, y: 7.5))
            film.line(to: NSPoint(x: 18.2, y: 7.5))
            film.curve(to: NSPoint(x: 19.5, y: 8.8), controlPoint1: NSPoint(x: 19.2, y: 7.5), controlPoint2: NSPoint(x: 19.5, y: 7.8))
            film.line(to: NSPoint(x: 19.5, y: 9.7))
            film.curve(to: NSPoint(x: 18.2, y: 11), controlPoint1: NSPoint(x: 19.5, y: 10.7), controlPoint2: NSPoint(x: 19.2, y: 11))
            film.line(to: NSPoint(x: 9, y: 11))
            film.close()
            for x in stride(from: 10.2, to: 18, by: 2.5) {
                film.appendRect(NSRect(x: x, y: 9.2, width: 1.2, height: 1.1))
            }
            for x in stride(from: 10.2, to: 12.5, by: 2.5) {
                film.appendRect(NSRect(x: x, y: 4.7, width: 1.2, height: 1.1))
            }
            film.windingRule = .evenOdd
            film.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
