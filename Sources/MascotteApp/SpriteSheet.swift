import CoreGraphics
import ImageIO
import Foundation

struct SpriteSheet {
    let image: CGImage
    let columns: Int
    let rows: Int
    let cellWidth: Int
    let cellHeight: Int

    init?(url: URL, columns: Int, rows: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        self.image = cgImage
        self.columns = columns
        self.rows = rows
        self.cellWidth = cgImage.width / columns
        self.cellHeight = cgImage.height / rows
    }
}
