//
//  PipelineModel+Types.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
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
