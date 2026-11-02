//
//  PipelineConnector.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
//

#if os(macOS)
import SwiftUI

/// Draws the arrows between stages.
enum PipelineConnector
{
    /// Draws an arrow from one stage's image to another's. A stage under the one it follows gets a straight line down from the
    /// bottom edge of the image to the top edge of the next. Otherwise the line leaves the right edge, runs through the space
    /// between the columns, and enters the left edge of the next stage.
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
                let Channel = A.maxX + PipelineMetrics.GapWidth / 2
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
