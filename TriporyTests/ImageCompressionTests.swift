import Foundation
import Testing
import UIKit
@testable import Tripory

@MainActor
@Suite("写真の圧縮")
struct ImageCompressionTests {

    @Test("画像として読めないデータはnilを返す")
    func rejectsNonImageData() {
        #expect(ImageCompression.compress(Data("これは画像ではない".utf8)) == nil)
    }

    @Test("長辺が上限を超える写真は上限まで縮小される")
    func downscalesLargePhoto() throws {
        let data = TestSupport.jpegData(width: 4000, height: 3000)
        let compressed = try #require(ImageCompression.compress(data, maxDimension: 1600))
        let image = try #require(UIImage(data: compressed))
        #expect(max(image.size.width, image.size.height) == 1600)
        // 縦横比が保たれている(4000:3000 = 4:3 → 1600:1200)
        #expect(abs(image.size.height - 1200) < 1)
    }

    @Test("縦長の写真でも長辺を基準に縮小される")
    func downscalesPortraitPhoto() throws {
        let data = TestSupport.jpegData(width: 1500, height: 3000)
        let compressed = try #require(ImageCompression.compress(data, maxDimension: 1200))
        let image = try #require(UIImage(data: compressed))
        #expect(max(image.size.width, image.size.height) == 1200)
        #expect(abs(image.size.width - 600) < 1)
    }

    @Test("上限より小さい写真は拡大されない")
    func doesNotUpscaleSmallPhoto() throws {
        let data = TestSupport.jpegData(width: 320, height: 240)
        let compressed = try #require(ImageCompression.compress(data, maxDimension: 1600))
        let image = try #require(UIImage(data: compressed))
        #expect(image.size.width == 320)
        #expect(image.size.height == 240)
    }

    @Test("圧縮後は元データより小さくなる")
    func compressionReducesDataSize() throws {
        let data = TestSupport.jpegData(width: 3000, height: 3000)
        let compressed = try #require(ImageCompression.compress(data))
        #expect(compressed.count < data.count)
    }

    @Test("圧縮結果はJPEGとして読み戻せる")
    func compressedDataIsDecodable() throws {
        let data = TestSupport.jpegData(width: 800, height: 600)
        let compressed = try #require(ImageCompression.compress(data))
        #expect(UIImage(data: compressed) != nil)
    }
}
