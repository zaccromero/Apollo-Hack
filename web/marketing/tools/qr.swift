import AppKit
import CoreImage
import Vision
let args = CommandLine.arguments
func fail(_ message: String) -> Never { fputs(message + "\n", stderr); exit(1) }
guard args.count == 3 else { fail("Usage: swift qr.swift HTTPS_URL OUTPUT.png") }
let payload = args[1]
let filter = CIFilter(name: "CIQRCodeGenerator")!
filter.setValue(Data(payload.utf8), forKey: "inputMessage")
filter.setValue("M", forKey: "inputCorrectionLevel")
guard let ci = filter.outputImage else { fail("QR generation failed") }
let scaled = ci.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
let extent = scaled.extent.insetBy(dx: -40, dy: -40)
let white = CIImage(color: CIColor.white).cropped(to: extent)
let composed = scaled.composited(over: white)
guard let image = CIContext().createCGImage(composed, from: extent) else { fail("QR raster failed") }
let bitmap = NSBitmapImageRep(cgImage: image)
guard let data = bitmap.representation(using: .png, properties: [:]) else { fail("PNG failed") }
// Read back the actual generated pixels before emitting any install configuration.
let request = VNDetectBarcodesRequest()
request.symbologies = [.qr]
try VNImageRequestHandler(cgImage: image).perform([request])
guard request.results?.first?.payloadStringValue == payload else { fail("QR decode does not match URL") }
try data.write(to: URL(fileURLWithPath: args[2]), options: .atomic)
print("QR_DECODE_MATCH: " + payload)
