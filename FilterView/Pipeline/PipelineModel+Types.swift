//
//  PipelineModel+Types.swift
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

import SwiftUI
import CoreGraphics

extension PipelineModel
{
    enum Kinds
    {
        /// The image the pipeline starts from.
        case Original
        /// Runs one filter. With no filter chosen it passes its image through unchanged.
        case Filter
        /// Combines two images.
        case Merge
        /// Divides the image into regions (`Layout`). Its image is the one it takes; the regions' lines of stages start under it.
        case Split
        /// Puts the final image of each region's line of stages into its place in the picture. See `PipelineModel.AddSplitter`.
        case Join
    }

    /// One step of the pipeline.
    struct Stage: Identifiable
    {
        /// The number shown on the stage. Never reused, even after the stage is deleted.
        let id: Int
        var Kind: Kinds
        /// The filter a `.Filter` stage runs. `nil` makes it a passthrough.
        var Selection: FilterSelection? = nil
        /// The stage whose image this one takes. For a merge, the background. `nil` only for the original.
        var Input: Int? = nil
        /// A merge's second image, merged onto the first.
        var Second: Int? = nil
        /// How a `.Split` or `.Join` stage divides the image.
        var Layout: SplitLayouts? = nil
        /// For a `.Join`: the last stage of each region's line, in region order. Kept up to date as stages are added to and removed from
        /// the lines.
        var Regions: [Int] = []
        /// True for a stage made by `Diverge`: it is drawn under the stage it takes its image from.
        var Under = false
        var MergeMode = MergeModes.Multiply
        var MergeAmount = 1.0
        /// True if the stage does nothing: its image is the one it took.
        var Skipped = false
        /// The image after this stage. `nil` until it has been made.
        var Output: CGImage? = nil
        /// True if the filter or merge failed. The stage then passes its first image on unchanged.
        var Failed = false

        /// Shown under the stage's image.
        var Name: String
        {
            switch Kind
            {
                case .Original:
                    return "Original"

                case .Filter:
                    if let Selection = Selection
                    {
                        return Selection.IsPipeline ? "Pipeline: \(Selection.DisplayName)" : Selection.DisplayName
                    }
                    return "Passthrough"

                case .Merge:
                    return "Merge \(Input ?? 0) + \(Second ?? 0): \(MergeMode.Title)"

                case .Split:
                    return "Partial Splitter: \(Layout?.Title ?? "")"

                case .Join:
                    return "Join Regions " + Regions.map{String($0)}.joined(separator: ", ")
            }
        }
    }

    /// Where a stage is drawn: its column (left to right) and row (top to bottom).
    struct GridPoint: Hashable
    {
        var Col: Int
        var Row: Int
    }

    /// A line from one stage to another.
    struct Edge
    {
        let From: Int
        let To: Int
    }
}
