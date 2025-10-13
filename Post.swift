import Foundation

struct Post: Identifiable, Equatable, Codable {
    var title: String
    var content: String
    var author: User
    var imageURL: URL?
    var isFavorite = false
    var timestamp = Date()
    var id = UUID()
    
    func contains(_ string: String) -> Bool {
        let properties = [title, content, author.name].map { $0.lowercased() }
        let query = string.lowercased()
        
        let matches = properties.filter { $0.contains(query) }
        return !matches.isEmpty
    }
}


extension Post: Codable {
    enum CodingKeys: CodingKey {
        case title, content, author, imageURL, timestamp, id
    }
}


extension Post {
    static let testPost = Post(
        title: "Look@",
        content: "What goes up must come down",
        author: User.testUser
    )
}
