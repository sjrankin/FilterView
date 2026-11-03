//
//  PipelineConnector.swift
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

/// Draws the arrows between stages.
enum PipelineConnector
{
    /// Draws an arrow from one stage's image to another's. A stage under the one it follows gets a straight line down from the
    /// bottom edge of the image to the top edge of the next. Otherwise the line leaves the right edge, runs through the space
    /// between the columns, and enters the left edge of the next stage. Where it turns depends on whether it goes up or down.
    static func Draw(_ Context: GraphicsContext, _ From: PipelineModel.GridPoint, _ To: PipelineModel.GridPoint)
    {
        let A = PipelineMetrics.ImageRect(From)
        let B = PipelineMetrics.ImageRect(To)
        var Line = Path()
        var Head = Path()
        if To.Col == From.Col && To.Row > From.Row
        {
            let End = CGPoint(x: B.midX, y: B.minY)
            Line.move(to: CGPoint(x: A.midX, y: A.maxY))
            Line.addLine(to: End)
            Head.move(to: End)
            Head.addLine(to: CGPoint(x: End.x - 6, y: End.y - 11))
            Head.addLine(to: CGPoint(x: End.x + 6, y: End.y - 11))
        }
        else
        {
            let Start = CGPoint(x: A.maxX, y: A.midY)
            let End = CGPoint(x: B.minX, y: B.midY)
            Line.move(to: Start)
            if abs(Start.y - End.y) > 0.5
            {
                // A line going up turns in the gap just before the stage it feeds, so it runs along its own row. Turning in the gap
                // after its source would send it along the row above, under the stages between, where it looks like it feeds the
                // first of them. A line going down turns after its source and runs along its target's row.
                let Channel = From.Row > To.Row ? B.minX - PipelineMetrics.GapWidth / 2 : A.maxX + PipelineMetrics.GapWidth / 2
                Line.addLine(to: CGPoint(x: Channel, y: Start.y))
                Line.addLine(to: CGPoint(x: Channel, y: End.y))
            }
            Line.addLine(to: End)
            Head.move(to: End)
            Head.addLine(to: CGPoint(x: End.x - 11, y: End.y - 6))
            Head.addLine(to: CGPoint(x: End.x - 11, y: End.y + 6))
        }
        Head.closeSubpath()
        Context.stroke(Line, with: .color(.gray), lineWidth: 2)
        Context.fill(Head, with: .color(.gray))
    }
}
#endif
