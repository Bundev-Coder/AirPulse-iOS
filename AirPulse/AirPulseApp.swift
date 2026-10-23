import SwiftUI

@main
struct AirPulseApp: App {
    var body: some Scene {
        WindowGroup {
            HostListView()
                .preferredColorScheme(.dark)
        }
    }
}
