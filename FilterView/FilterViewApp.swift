import SwiftUI

#if os(macOS)
/// The macOS version should terminate the app when the last window (or only window) closes. This requires an `AppDelegate`, which iOS
/// does not support. Hence the conditional compilation.
final class AppDelegate: NSObject, NSApplicationDelegate
{
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    {
        return true
    }
}
#endif

@main struct FilterViewApp: App
{
#if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var Delegate
#endif
    
    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
        }
    }
}
