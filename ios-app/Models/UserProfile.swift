import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: String
    var displayName: String
    var email: String
    var avatarUrl: String?
    var graphColor: String
    var createdAt: Date

    init(id: String, displayName: String, email: String) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.graphColor = "#2B9B8F"
        self.createdAt = Date()
    }
}
