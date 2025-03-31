import SwiftUI

@main
struct SwiftSweeper: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 450, height: 580)  // Set fixed width and height

        }
        .windowResizability(.contentSize)
    }
}
