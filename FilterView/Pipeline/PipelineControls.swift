//
//  PipelineControls.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
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

#if os(macOS)
import SwiftUI

/// The Pipeline and Set buttons under the input controls. Pipeline opens and closes the Pipeline window; Set adds the current
/// filter to the pipeline in that window.
struct PipelineControls: View
{
    @Environment(PipelineModel.self) private var Pipeline
    @Environment(\.openWindow) private var OpenWindow
    @Environment(\.dismissWindow) private var DismissWindow
    /// True if a filter is selected, so there is something to add.
    var HasFilter: Bool
    /// Called when the user taps Set.
    var OnSet: () -> Void
    /// Called when the user taps Conditional.
    var OnConditional: () -> Void

    var body: some View
    {
        VStack(alignment: .leading)
        {
            HStack
            {
                Toggle("Pipeline", isOn: Binding(get: { Pipeline.IsOpen },
                                                 set: { Opened in
                                                     if Opened
                                                     {
                                                         OpenWindow(id: PipelineWindow.ID)
                                                     }
                                                     else
                                                     {
                                                         DismissWindow(id: PipelineWindow.ID)
                                                     }
                                                 }))
                    .toggleStyle(.button)
                Button("Set")
                {
                    OnSet()
                }
                // Set only means something while the Pipeline window is there to show the result.
                .disabled(!Pipeline.IsOpen || !HasFilter)
                Button("Conditional")
                {
                    OnConditional()
                }
                .disabled(!Pipeline.IsOpen)
                Spacer()
            }
        }
        .alert("Cannot Add Pipeline",
               isPresented: Binding(get: { Pipeline.Problem != nil }, set: { _ in Pipeline.Problem = nil }))
        {
            Button("OK") {}
        }
        message:
        {
            Text(Pipeline.Problem ?? "")
        }
    }
}
#endif
