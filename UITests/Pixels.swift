import XCTest

/// A readable label differs clearly from its button's fill, taken as the median brightness of the button's central half.
/// The central crop keeps the page showing through a capsule's rounded corners out of the count.
@MainActor
func assertLabelContrasts(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let brightness = brightnessValues(inMiddleOf: element.screenshot().image).sorted()
    guard !brightness.isEmpty else { return XCTFail("could not read the button's pixels", file: file, line: line) }
    let fill = brightness[brightness.count / 2]
    let labelShare = Double(brightness.count { abs($0 - fill) > 48 }) / Double(brightness.count)
    XCTAssertGreaterThan(labelShare, 0.01, "the label blends into its fill", file: file, line: line)
}

/// OLED black: the button's fill (the median of its central half, as above) is black, not iOS's grey.
@MainActor
func assertFillIsBlack(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let brightness = brightnessValues(inMiddleOf: element.screenshot().image).sorted()
    guard !brightness.isEmpty else { return XCTFail("could not read the button's pixels", file: file, line: line) }
    let fill = brightness[brightness.count / 2]
    XCTAssertLessThan(fill, 12, "\(element.label) is filled grey (\(fill)/255), not black", file: file, line: line)
}

/// Mean of R, G and B (0–255) for each pixel in the central half of the image.
private func brightnessValues(inMiddleOf image: UIImage) -> [Int] {
    guard let full = image.cgImage else { return [] }
    let crop = CGRect(x: full.width / 4, y: full.height / 4, width: full.width / 2, height: full.height / 2)
    guard let middle = full.cropping(to: crop) else { return [] }
    let width = middle.width
    let height = middle.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = pixels.withUnsafeMutableBytes { buffer in
        guard
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        context.draw(middle, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else { return [] }
    return stride(from: 0, to: pixels.count, by: 4).map { offset in
        (Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])) / 3
    }
}
