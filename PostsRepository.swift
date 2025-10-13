import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift


protocol PostsRepositoryProtocol {
    var user: User { get }
    func fetchAllPosts() async throws -> [Post]
    func fetchPosts(by author: User) async throws -> [Post]
    func fetchLikedPosts() async throws -> [Post]
    func create(_ post: Post) async throws
    func delete(_ post: Post) async throws
    func like(_ post: Post) async throws
    func removeLike(_ post: Post) async throws
}


extension PostsRepositoryProtocol {
    func canDelete(_ post: Post) -> Bool {
        post.author.id == user.id
    }
}


#if DEBUG
struct PostsRepositoryStub: PostsRepositoryProtocol {

    let state: Loadable<[Post]>
    let user = User.testUser
    
    func fetchAllPosts() async throws -> [Post] {
        return try await state.simulate()
    }

    func fetchPosts(by author: User) async throws -> [Post] {
        return try await state.simulate()
    } 

    func fetchLikedPosts() async throws -> [Post] {
    return try await state.simulate()
}
    
    func create(_ post: Post) async throws {}

    func delete(_ post: Post) async throws {}

    func like(_ post: Post) async throws {}

    func removeLike(_ post: Post) async throws {}
}
#endif


struct PostsRepository: PostsRepositoryProtocol {
    let user: User
    let postsReference = Firestore.firestore().collection("posts_v2")
    let likesReference = Firestore.firestore().collection("likes")
    
    func fetchAllPosts() async throws -> [Post] {
        return try await fetchPosts(from: postsReference)
    }

    func fetchPosts(by author: User) async throws -> [Post] {
        return try await fetchPosts(from: postsReference.whereField("author.id", isEqualTo: author.id))
    }
    
    func fetchLikedPosts() async throws -> [Post] {
        let likes = try await fetchLikes()
        guard !likes.isEmpty else { return [] }
        return try await postsReference
            .whereField("id", in: likes.map(\.uuidString))
            .order(by: "timestamp", descending: true)
            .getDocuments(as: Post.self)
            .map { post in
                post.setting(\isFavorite, to: true)
            }
    }
    
    
    func create(_ post: Post) async throws {
        var post = post
        if let imageFileURL = post.imageURL {
            post.imageURL = try await StorageFile
                .with(namespace: "posts", identifier: post.id.uuidString)
                .putFile(from: imageFileURL)
                .getDownloadURL()
        }
        let document = postsReference.document(post.id.uuidString)
        try await document.setData(from: post)
    }

    func delete(_ post: Post) async throws {
        precondition(canDelete(post))
        let document = postsReference.document(post.id.uuidString)
        try await document.delete()
        let image = post.imageURL.map(StorageFile.atURL(_:))
        try await image?.delete()
    }

    func like(_ post: Post) async throws {
        let like = Like(postID: post.id, userID: user.id)
        let document = likesReference.document(like.id)
        try await document.setData(from: like)
    }

    func removeLike(_ post: Post) async throws {
        let like = Like(postID: post.id, userID: user.id)
        let document = likesReference.document(like.id)
        try await document.delete()
    }
}


private extension PostsRepository {
    func fetchPosts(from query: Query) async throws -> [Post] {
        let (posts, likes) = try await (
            query.order(by: "timestamp", descending: true).getDocuments(as: Post.self),
            fetchLikes()
        )
        return posts.map { post in
            post.setting(\.isFavorite, to: likes.contains(post.id))
        }
    }
    
    func fetchLikes() async throws -> [Post.ID] {
        return try await likesReference
            .whereField("userID", isEqualTo: user.id)
            .getDocuments(as: Like.self)
            .map(\.postID)
    }
    
    struct Like: Identifiable, Codable {
        var id: String {
            postID.uuidString + "-" + userID
        }
        let postID: Post.ID
        let userID: User.ID
    }
}


private extension Post {
    func setting<T>(_ property: WritableKeyPath<Post, T>, to newValue: T) -> Post {
        var post = self
        post[keyPath: property] = newValue
        return post
    }
}


