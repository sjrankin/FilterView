//
//  PipelineMergeEditSheet.swift
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

/// The dialog that changes how an existing merge stage combines its two images.
struct MergeEditSheet: View
{
    /// The merge stage being edited.
    let StageID: Int
    @Environment(PipelineModel.self) private var Pipeline
    @Environment(\.dismiss) private var Dismiss
    @State var Mode: MergeModes
    @State var Amount: Double

    var body: some View
    {
        VStack(alignment: .leading, spacing: 14)
        {
            Text("Edit merge \(StageID)")
                .font(.headline)
            Picker("Mode", selection: $Mode)
            {
                ForEach(MergeModes.allCases)
                {
                    Text($0.Title).tag($0)
                }
            }
            HStack
            {
                Text("Amount: \(Amount, format: .percent.precision(.fractionLength(0)))")
                    .monospacedDigit()
                    .frame(width: 110, alignment: .leading)
                Slider(value: $Amount, in: 0 ... 1)
            }
            HStack
            {
                Spacer()
                Button("Cancel")
                {
                    Dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Apply")
                {
                    Pipeline.UpdateMerge(StageID, Mode: Mode, Amount: Amount)
                    Dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 380)
    }
}
#endif
