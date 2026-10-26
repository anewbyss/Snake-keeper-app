import Foundation
import SwiftData

@Model
final class SnakePhoto {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var imageData: Data = Data()
    @Attribute(.externalStorage) var thumbnailData: Data = Data()
    var dateTaken: Date = Date()
    var caption: String = ""
    var isCover: Bool = false
    var snake: Snake?

    init(imageData: Data, thumbnailData: Data, dateTaken: Date = .now) {
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.dateTaken = dateTaken
    }
}
