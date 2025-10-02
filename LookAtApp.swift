import SwiftUI
import Firebase

@main
struct LookAtApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            PostsList()
        }
    }
}