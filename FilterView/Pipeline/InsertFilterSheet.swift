//
//  InsertFilterSheet.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
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

/// Identifies the stage a filter is to be inserted next to, and on which side.
struct InsertRequest: Identifiable
{
    let id: Int
    /// True to insert after the stage, false to insert before it.
    let After: Bool
}

/// The dialog that asks what kind of filter to insert next to a stage. It shows the same filter tree as the main window, including the
/// saved pipelines, so a stage is made the normal way. The options start as the filter's defaults, not the main window's settings, and can
/// be changed afterwards with Edit Filter. Passthrough, under Infrastructure, makes an empty stage.
struct InsertFilterSheet: View
{
    let StageID: Int
    let After: Bool
    @Environment(PipelineModel.self) private var Pipeline
    @Environment(\.dismiss) private var Dismiss
    @State private var Chosen: FilterSelection? = nil
    @State private var Root = try? FilterTreeLoader.Load(Resource: "FilterTree")

    var body: some View
    {
        let Problem = Chosen.flatMap{Pipeline.NestingProblem(for: $0)}
        VStack(alignment: .leading)
        {
            Text("Insert a filter \(After ? "after" : "before") stage \(StageID): \(Pipeline.StageFor(StageID)?.Name ?? "")")
                .font(.headline)
            FilterTreeView(Root: Root, Selection: $Chosen, UsesSavedOptions: false)
                .frame(minHeight: 280)
            HStack
            {
                Text("Filter")
                Text(Chosen?.DisplayName ?? "None chosen")
                    .bold()
                    .foregroundStyle(Chosen == nil ? .secondary : .primary)
                Spacer()
            }
            if let Problem = Problem
            {
                Text(Problem)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack
            {
                Spacer()
                Button("Cancel")
                {
                    Dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Insert")
                {
                    if After
                    {
                        Pipeline.InsertFilter(After: StageID, With: Chosen)
                    }
                    else
                    {
                        Pipeline.InsertFilter(Before: StageID, With: Chosen)
                    }
                    Dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(Chosen == nil || Problem != nil)
            }
        }
        .padding()
        .frame(width: 420, height: 520)
    }
}
#endif
