//
//  PipelineFinalView.swift
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

/// The right side of the Pipeline window: the final image of the pipeline, kept up to date as stages and filter settings change, with
/// a border on its left edge that the user drags to make the view wider or narrower. It is never wider than a third of the window.
struct PipelineFinalView: View
{
    /// The widest the view may be, as a fraction of the width of the whole window.
    static let MaxFraction = 1.0 / 3.0
    /// The narrowest the view may be.
    static let MinWidth = 120.0

    @Environment(PipelineModel.self) private var Pipeline
    /// The width of the whole window, which limits the width of the view.
    let WindowWidth: CGFloat
    /// The width the user has dragged the view to.
    @Binding var Width: CGFloat
    /// The width when the current drag began.
    @State private var DragStart: CGFloat? = nil

    /// The width actually shown, never over the limit even if the window has been made smaller.
    var ShownWidth: CGFloat
    {
        Self.Clamped(Width, WindowWidth: WindowWidth)
    }

    /// Keeps a width between the narrowest and widest the view may be.
    /// - Parameter Wanted: The width asked for.
    /// - Parameter WindowWidth: The width of the whole window.
    static func Clamped(_ Wanted: CGFloat, WindowWidth: CGFloat) -> CGFloat
    {
        max(MinWidth, min(Wanted, max(MinWidth, WindowWidth * MaxFraction)))
    }

    var body: some View
    {
        HStack(spacing: 0)
        {
            // The border that resizes the view.
            Rectangle()
                .fill(.separator)
                .frame(width: 1)
                .overlay
                {
                    Color.clear
                        .frame(width: 8)
                        .contentShape(.rect)
                        .pointerStyle(.columnResize)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                .onChanged
                                {
                                    Drag in
                                    let Start = DragStart ?? ShownWidth
                                    DragStart = Start
                                    Width = Self.Clamped(Start - Drag.translation.width, WindowWidth: WindowWidth)
                                }
                                .onEnded
                                {
                                    _ in
                                    DragStart = nil
                                })
                }
            VStack
            {
                if let Final = Pipeline.FinalImage
                {
                    Image(decorative: Final, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(Checkerboard(SquareSize: 8))
                }
                else
                {
                    Text("No final image yet")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .background(.black.opacity(0.05))
        }
        .frame(width: ShownWidth)
    }
}
#endif
