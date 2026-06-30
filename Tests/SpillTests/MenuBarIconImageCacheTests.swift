import CoreGraphics
import ImageIO
@testable import Spill
import UniformTypeIdentifiers
import XCTest

final class MenuBarIconImageCacheTests: XCTestCase {
    func testImageCacheDoesNotDecodeOnMainThreadBeforePrepare() async throws {
        let data = try Self.makePNGData()
        let cache = MenuBarIconImageCache.shared
        cache.removeAllObjects()

        let mainThreadVerified = await MainActor.run {
            Thread.isMainThread
        }
        XCTAssertTrue(mainThreadVerified)

        let mainThreadMiss = await MainActor.run {
            cache.image(for: data) == nil
        }
        XCTAssertTrue(mainThreadMiss)

        let prepared = await Task.detached(priority: .utility) {
            cache.prepareImage(for: data)
        }.value
        XCTAssertTrue(prepared)

        let mainThreadHit = await MainActor.run {
            cache.image(for: data) != nil
        }
        XCTAssertTrue(mainThreadHit)
    }

    private static func makePNGData() throws -> Data {
        let width = 2
        let height = 2
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw IconFixtureError.contextCreationFailed
        }

        context.setFillColor(CGColor(red: 0.1, green: 0.6, blue: 0.85, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            throw IconFixtureError.imageCreationFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw IconFixtureError.destinationCreationFailed
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw IconFixtureError.finalizeFailed
        }

        return data as Data
    }
}

private enum IconFixtureError: Error {
    case contextCreationFailed
    case imageCreationFailed
    case destinationCreationFailed
    case finalizeFailed
}
