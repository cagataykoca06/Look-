import Foundation

@MainActor
class PostsViewModel: ObservableObject {
    @Published var posts: Loadable<[Post]> = .loading

    private let postsRepository: PostsRepositoryProtocol

    init(postsRepository: PostsRepositoryProtocol = PostsRepository()) {
        self.postsRepository = postsRepository
    }

    func makeCreateAction() -> NewPostForm.CreateAction {
        return { [weak self] post in
            try await self?.PostsRepository.create(post)
            self?.posts.insert(post, at:0 )
        }
    }

    func fetchPosts() {
        Task {
            do {
                posts = .loaded(try await
    PostsRepository.fetchPosts())
            } catch {
                print("[PostViewModel] Cannot fetch posts: \(error)")
                posts = .error(error)
            }
        }
    }

}
