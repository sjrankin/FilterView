//
//  OptionView.swift
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

struct OptionView: View
{
    /// The selected filter, whose options are edited in the panel under the image information.
    @Binding var Selection: FilterSelection?
    var SourceName: String = "Built-in"
    var FilterName: String = "None"
    /// How long the last render took. `nil` shows a dash.
    var RenderTime: Duration? = nil
    /// Size in pixels of the image being filtered. `nil` shows a dash.
    var ImageSize: CGSize? = nil
    /// The original, unfiltered image, shown as a thumbnail. `nil` shows a placeholder.
    var SourceImage: Image? = nil

    /// The image size as "width × height px", or a dash if it is not known.
    private var ImageSizeText: String
    {
        guard let ImageSize = ImageSize else
        {
            return "-"
        }
        let Width = Int(ImageSize.width).formatted(.number.grouping(.never))
        let Height = Int(ImageSize.height).formatted(.number.grouping(.never))
        return "\(Width) × \(Height) px"
    }

    /// The render time in milliseconds, or a dash if there is none.
    private var RenderTimeText: String
    {
        guard let RenderTime = RenderTime else
        {
            return "-"
        }
        return RenderTime.formatted(.units(allowed: [.milliseconds], width: .abbreviated, fractionalPart: .show(length: 1)))
    }

    var body: some View
    {
        VStack
        {
            HStack
            {
                VStack
                {
                    HStack
                    {
                        Text("Source")
                            .fixedSize()
                        Text(SourceName)
                            .bold()
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    HStack
                    {
                        Text("Size")
                            .fixedSize()
                        Text(ImageSizeText)
                            .bold()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                    }
                    HStack
                    {
                        Text("Render")
                            .fixedSize()
                        Text(RenderTimeText)
                            .bold()
                        Spacer()
                    }
                }
                // The original, unfiltered image, as a thumbnail. A placeholder shows until there is one.
                (SourceImage ?? Image(systemName: "photo"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 100, maxHeight: 100)
                    .background(.black)
            }
            Divider()
            FilterOptionsView(Selection: $Selection)
            Divider()
            HStack
            {
                Text("Filter")
                Text(FilterName)
                    .bold()
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

#Preview
{
    @Previewable @State var Selected: FilterSelection? = nil
    OptionView(Selection: $Selected)
}
