//
//  HistogramView.swift
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

/// The histogram of an image in three dimensions: the red, green and blue curves each stand upright on a line of their own, one behind
/// the other, on a black background. Drag to turn the view, which shows what one curve hides of another; double-click to put the view
/// back as it started. The mouse wheel, or a pinch, zooms. Heights are square roots of the counts, so small numbers can still be seen next to a tall spike.
struct HistogramView: View
{
    /// How the view is turned when it starts and after a reset, in degrees.
    static let StartYaw = -28.0
    static let StartPitch = 24.0

    let Histogram: ColorHistogram
    /// How tall the graph is.
    var Height: CGFloat = 150

    /// The turn around the vertical axis, in degrees.
    @State private var Yaw = StartYaw
    /// The tilt, in degrees. Positive looks down on the graph from above.
    @State private var Pitch = StartPitch
    /// How much the graph is magnified. 1.0 is as it starts.
    @State private var Zoom = 1.0
    /// The zoom when the current pinch began.
    @State private var PinchStart: Double? = nil
    #if os(macOS)
    @State private var WheelWatcher = WheelZoomWatcher()
    #endif
    /// The turn and tilt when the current drag began.
    @State private var DragStart: (Yaw: Double, Pitch: Double)? = nil

    var body: some View
    {
        Canvas
        {
            Context, Size in
            Draw(Context, Size)
        }
        .frame(height: Height)
        .background(.black, in: .rect(cornerRadius: 3))
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged
                {
                    Drag in
                    let Start = DragStart ?? (Yaw, Pitch)
                    DragStart = Start
                    Yaw = Start.Yaw + Drag.translation.width * 0.6
                    Pitch = min(max(Start.Pitch + Drag.translation.height * 0.6, -89), 89)
                }
                .onEnded
                {
                    _ in
                    DragStart = nil
                })
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged
                {
                    Pinch in
                    let Start = PinchStart ?? Zoom
                    PinchStart = Start
                    Zoom = Self.Clamped(Start * Pinch.magnification)
                }
                .onEnded
                {
                    _ in
                    PinchStart = nil
                })
        #if os(macOS)
        // The mouse wheel zooms while the pointer is over the graph.
        .onContinuousHover
        {
            Phase in
            switch Phase
            {
                case .active:
                    WheelWatcher.IsInside = true
                case .ended:
                    WheelWatcher.IsInside = false
            }
        }
        .onAppear
        {
            WheelWatcher.Start
            {
                Change in
                Zoom = Self.Clamped(Zoom * Change)
            }
        }
        .onDisappear
        {
            WheelWatcher.Stop()
        }
        #endif
        // A double click is the one place a tap's count matters.
        .onTapGesture(count: 2)
        {
            withAnimation
            {
                Yaw = Self.StartYaw
                Pitch = Self.StartPitch
                Zoom = 1.0
            }
        }
        .help("Drag to turn the histogram, scroll to zoom. Double-click to reset the view.")
        .accessibilityLabel("Three-dimensional color histogram")
    }

    /// Keeps a zoom between a half and four times the starting size.
    static func Clamped(_ Value: Double) -> Double
    {
        min(max(Value, 0.5), 4.0)
    }

    /// Draws the three curves, farthest first, so nearer ones cover them.
    private func Draw(_ Context: GraphicsContext, _ Size: CGSize)
    {
        let Peak = Double(max(Histogram.Red.max() ?? 0, Histogram.Green.max() ?? 0, Histogram.Blue.max() ?? 0)).squareRoot()
        guard Peak > 0 else
        {
            return
        }
        let Across = Size.width * 0.78 * Zoom
        let Up = Size.height * 0.42 * Zoom
        let Apart = Size.height * 0.28 * Zoom
        let Turn = Yaw * .pi / 180
        let Tilt = Pitch * .pi / 180

        /// Where a point of the graph falls on the screen, and how near it is to the viewer (larger is nearer).
        func Place(_ X: Double, _ Y: Double, _ Z: Double) -> (Point: CGPoint, Near: Double)
        {
            let AcrossTurned = X * cos(Turn) + Z * sin(Turn)
            let DepthTurned = -X * sin(Turn) + Z * cos(Turn)
            let UpTilted = Y * cos(Tilt) - DepthTurned * sin(Tilt)
            let Near = Y * sin(Tilt) + DepthTurned * cos(Tilt)
            return (CGPoint(x: Size.width / 2 + AcrossTurned, y: Size.height * 0.62 - UpTilted), Near)
        }

        // Red is in front, then green, then blue.
        let Channels: [(Name: String, Counts: [Int], Tint: Color, Lane: Double)] =
            [("R", Histogram.Red, .red, 1), ("G", Histogram.Green, .green, 0), ("B", Histogram.Blue, .blue, -1)]
        let Ordered = Channels.sorted
        {
            Place(0, 0, $0.Lane * Apart).Near < Place(0, 0, $1.Lane * Apart).Near
        }
        for Channel in Ordered
        {
            let Z = Channel.Lane * Apart
            var Curve = Path()
            for (Value, Count) in Channel.Counts.enumerated()
            {
                let X = (Double(Value) / 255.0 - 0.5) * Across
                let Point = Place(X, Double(Count).squareRoot() / Peak * Up, Z).Point
                if Value == 0
                {
                    Curve.move(to: Point)
                }
                else
                {
                    Curve.addLine(to: Point)
                }
            }
            let Left = Place(-0.5 * Across, 0, Z).Point
            let Right = Place(0.5 * Across, 0, Z).Point
            var Wall = Curve
            Wall.addLine(to: Right)
            Wall.addLine(to: Left)
            Wall.closeSubpath()
            Context.fill(Wall, with: .color(Channel.Tint.opacity(0.55)))
            // The solid outline of the curve, and the line the curve stands on.
            Context.stroke(Curve, with: .color(Channel.Tint), lineWidth: 1)
            var Base = Path()
            Base.move(to: Left)
            Base.addLine(to: Right)
            Context.stroke(Base, with: .color(.white.opacity(0.5)), lineWidth: 1)
            Context.draw(Text(Channel.Name).font(.caption2.bold()).foregroundStyle(Channel.Tint),
                         at: CGPoint(x: Left.x - 8, y: Left.y))
        }
    }
}
