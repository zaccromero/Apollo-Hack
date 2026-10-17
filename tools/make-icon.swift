import AppKit
let output = CommandLine.arguments[1]
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 0.04, green: 0.09, blue: 0.13, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
NSColor(calibratedRed: 0.55, green: 0.91, blue: 0.72, alpha: 1).setStroke()
let a = NSBezierPath(); a.lineWidth = 66; a.lineCapStyle = .round; a.lineJoinStyle = .round
a.move(to: NSPoint(x: 298,y: 255)); a.line(to: NSPoint(x: 512,y: 768)); a.line(to: NSPoint(x: 726,y: 255)); a.stroke()
let cross = NSBezierPath(); cross.lineWidth = 54; cross.lineCapStyle = .round; cross.move(to:NSPoint(x:388,y:442)); cross.line(to:NSPoint(x:636,y:442)); cross.stroke()
NSColor(calibratedRed: 0.87, green: 0.96, blue: 1, alpha: 1).setStroke()
let arc = NSBezierPath(); arc.lineWidth = 20; arc.appendArc(withCenter:NSPoint(x:512,y:512),radius:375,startAngle:210,endAngle:36,clockwise:true); arc.stroke()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath:output))
