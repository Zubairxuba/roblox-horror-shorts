// Park the mouse pointer in the bottom-right corner of the main screen (outside Studio's viewport) for recording.
import CoreGraphics
let b = CGDisplayBounds(CGMainDisplayID())
CGWarpMouseCursorPosition(CGPoint(x: b.maxX - 2, y: b.maxY - 2))
CGAssociateMouseAndMouseCursorPosition(1)
