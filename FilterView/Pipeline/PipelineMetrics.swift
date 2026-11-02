//
//  PipelineMetrics.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
//

#if os(macOS)
import SwiftUI

/// Where the stages go in the window and how big they are.
enum PipelineMetrics
{
    /// Width and height of each stage's image.
    static let Side: CGFloat = 168
    /// Space between one column of images and the next, where the lines run.
    static let GapWidth: CGFloat = 70
    /// Room under an image for its name and a note.
    static let LabelHeight: CGFloat = 64
    /// Space between one row of stages and the next.
    static let GapHeight: CGFloat = 36
    /// Space around everything.
    static let Margin: CGFloat = 24
    static let CellWidth = Side + GapWidth
    static let CellHeight = Side + LabelHeight + GapHeight

    /// The image of the stage at this place.
    static func ImageRect(_ Point: PipelineModel.GridPoint) -> CGRect
    {
        CGRect(x: Margin + CGFloat(Point.Col) * CellWidth, y: Margin + CGFloat(Point.Row) * CellHeight, width: Side, height: Side)
    }
}
#endif
