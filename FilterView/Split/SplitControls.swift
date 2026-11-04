//
//  SplitControls.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/4/26.
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

/// The buttons that divide the image into regions, each with its own filter, and say which region is being edited.
struct SplitControls: View
{
    /// The current division. `nil` when the image is not divided.
    var Setup: SplitSetup?
    /// Called when the user taps a layout's button. Tapping the layout already in use puts the image back together.
    var OnChoose: (SplitLayouts) -> Void
    /// Called when the user taps Remove Regions, which drops every region's filter and puts the image back together.
    var OnRemove: () -> Void

    var body: some View
    {
        HStack
        {
            ForEach(SplitLayouts.allCases)
            {
                Layout in
                Toggle(isOn: Binding(get: { Setup?.Layout == Layout }, set: { _ in OnChoose(Layout) }))
                {
                    Label(Layout.Title, systemImage: Layout.SymbolName)
                }
                .toggleStyle(.button)
                .labelStyle(.iconOnly)
                .help("Give each part of the image its own filter: \(Layout.Title.lowercased())")
            }
            if let Setup = Setup
            {
                Text("Choose a part of the image, then a filter. Editing: \(Setup.Layout.RegionName(Setup.Active))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            Button("Remove Regions", systemImage: "xmark.circle")
            {
                OnRemove()
            }
            .disabled(Setup == nil)
            .help("Remove the filters of all the regions and put the image back together")
        }
    }
}

#Preview
{
    @Previewable @State var Current: SplitSetup? = SplitSetup(Layout: .Quadrants, First: nil)
    SplitControls(Setup: Current, OnChoose:
    {
        Layout in
        Current = Current?.Layout == Layout ? nil : SplitSetup(Layout: Layout, First: nil)
    }, OnRemove: { Current = nil })
    .padding()
}
