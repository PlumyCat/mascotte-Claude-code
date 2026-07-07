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

    func cellImage(row: Int, column: Int) -> CGImage? {
        guard row >= 0, row < rows, column >= 0, column < columns else { return nil }
        let rect = CGRect(
            x: column * cellWidth,
            y: row * cellHeight,
            width: cellWidth,
            height: cellHeight
        )
        return image.cropping(to: rect)
    }
}
