//
//  PipelineMetrics.swift
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
