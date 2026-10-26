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
    /// Last edit, for sync.
    var updatedAt: Date = Date()
    var snake: Snake?

    init(imageData: Data, thumbnailData: Data, dateTaken: Date = .now) {
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.dateTaken = dateTaken
    }
}

extension SnakePhoto: Syncable {
    static let syncType = "photos"
}
