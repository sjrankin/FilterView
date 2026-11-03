//
//  FilterViewApp.swift
//  FilterView
//
//  Copyright 2026 Stuart Rankin
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

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
