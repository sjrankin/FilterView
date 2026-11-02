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
    
    /// The pipeline of filters, shared by the main window and the Pipeline window.
    @State private var Pipeline = PipelineModel()

    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
                .environment(Pipeline)
        }
#if os(macOS)
        Window("Pipeline", id: PipelineWindow.ID)
        {
            PipelineWindow()
                .environment(Pipeline)
        }
        .defaultSize(width: 900, height: 420)
#endif
    }
}
