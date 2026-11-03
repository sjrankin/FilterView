//
//  StageOptionsSheet.swift
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

/// Identifies the stage an options dialog is for.
struct EditRequest: Identifiable
{
    let id: Int
}

/// The pop-up that edits the options of one filter stage, with the same controls as the options panel of the main window. The
/// controls change a copy: OK puts the options on the stage, Cancel leaves the stage as it was. Neither touches the values the main
/// window remembers.
struct StageOptionsSheet: View
{
    let StageID: Int
    @State private var Draft: FilterSelection
    @Environment(PipelineModel.self) private var Pipeline
    @Environment(\.dismiss) private var Dismiss

    init(StageID: Int, Selection: FilterSelection)
    {
        self.StageID = StageID
        _Draft = State(initialValue: Selection)
    }

    var body: some View
    {
        VStack(alignment: .leading)
        {
            Text("Edit \(Draft.DisplayName)")
                .font(.headline)
            ScrollView
            {
                VStack(alignment: .leading)
                {
                    ForEach(Draft.Parameters)
                    {
                        Parameter in
                        FilterParameterRow(Filter: Draft.Filter, Parameter: Parameter,
                                           InitialValue: Draft.Options?[Parameter.Key] ?? Parameter.Default, Persist: false)
                        {
                            Value in
                            Draft = Draft.Updating(Key: Parameter.Key, Value: Value)
                        }
                        .disabled(!Draft.IsEnabled(Parameter))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing)
            }
            .scrollIndicators(.visible)
            Divider()
            HStack
            {
                Spacer()
                Button("Cancel")
                {
                    Dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("OK")
                {
                    Pipeline.UpdateOptions(StageID, To: Draft)
                    Dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 380, height: 420)
    }
}
#endif
