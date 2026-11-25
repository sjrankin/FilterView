//
//  ControlStack.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
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

struct ControlStack: View
{
    var FilterTreeData: FilterNode? = nil
    @Binding var Selection: FilterSelection?
    /// Describes where the image being filtered came from. Shown in `OptionView`.
    var SourceName: String = "Built-in"
    /// Name of the current filter, shown in `OptionView`.
    var FilterName: String = "None"
    /// How long the last render took, shown in `OptionView`. `nil` if unknown.
    var RenderTime: Duration? = nil
    /// Size in pixels of the image being filtered, shown in `OptionView`. `nil` if unknown.
    var ImageSize: CGSize? = nil
    /// The original, unfiltered image, shown as a thumbnail in `OptionView`. `nil` if there is none.
    var SourceImage: Image? = nil
    /// The color histogram of the original image, shown in `OptionView`. `nil` if there is none yet.
    var SourceHistogram: ColorHistogram? = nil
    /// Height of the options box. The user changes it by dragging the divider above it.
    @State private var OptionHeight: CGFloat = 300
    /// True once the options box has been made taller so the filter list starts 20% shorter. Done once, so the user's drags stand.
    @State private var DidShrinkList = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var SizeClass
    #endif

    var body: some View
    {
        // No spacing: the divider has its own padding.
        VStack(alignment: .leading, spacing: 0)
        {
            FilterTreeView(Root: FilterTreeData, Selection: $Selection)
                .frame(minHeight: 100)
            PanelDivider(Size: $OptionHeight, Direction: .vertical, MinSize: 120, MaxSize: 500)
            OptionView(Selection: $Selection, SourceName: SourceName, FilterName: FilterName, RenderTime: RenderTime, ImageSize: ImageSize,
                       SourceImage: SourceImage, SourceHistogram: SourceHistogram)
                .frame(height: OptionHeight)
        }
        .onGeometryChange(for: CGFloat.self)
        {
            $0.size.height
        }
        action:
        {
            Total in
            // The list gets what the options box leaves. Growing the box by a fifth of the list's height makes the list 20% shorter,
            // leaving that room to the options and histogram.
            if !DidShrinkList, Total > 0
            {
                DidShrinkList = true
                let List = max(Total - OptionHeight, 0)
                OptionHeight = min(OptionHeight + List * 0.2, 500)
            }
        }
        #if os(iOS)
        // On a narrow screen this panel sits under the image and is short, so the options start small.
        .onAppear
        {
            if SizeClass == .compact
            {
                OptionHeight = 130
            }
        }
        #endif
    }
}

#Preview
{
    @Previewable @State var Selected: FilterSelection? = nil
    ControlStack(Selection: $Selected)
}
