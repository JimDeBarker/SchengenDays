import SwiftUI

@main
struct SchengenDaysApp: App {
    /// Built at launch on purpose: when iOS relaunches the app in the
    /// background for a significant location change, the location manager
    /// has to exist before the pending update can be delivered.
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            HomeView(model: model)
        }
    }
}
