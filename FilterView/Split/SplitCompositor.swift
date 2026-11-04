//
//  SplitCompositor.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/4/26.
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

import CoreGraphics

/// Puts the parts of several images together: each region of the result comes from the same region of one image.
nonisolated enum SplitCompositor
{
    /// Builds the result.
    /// - Parameter Background: The unfiltered image. Its size is the result's size, and it fills any region that has no image.
    /// - Parameter Layout: How the image is divided.
    /// - Parameter Regions: The image for each region, in region order. Each is a whole image (a filter's result for the whole picture);
    /// only its part for that region is used. If it is a different size from the background (some filters change the size), its part is
    /// scaled to fit. `nil`, or a missing entry, uses the background.
    /// - Returns: The combined image, or `nil` if it could not be made.
    static func Compose(Background: CGImage, Layout: SplitLayouts, Regions: [CGImage?]) -> CGImage?
    {
        // The result keeps the background's colors as they are, so a region that is not changed looks the same as the original.
        var Space = Background.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        if Space.model != .rgb
        {
            Space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        }
        guard Background.width > 0,
              Background.height > 0,
              let Context = CGContext(data: nil, width: Background.width, height: Background.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: Space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else
        {
            return nil
        }
        // A filtered region replaces what was there, transparency included, so it is not drawn over the original.
        Context.setBlendMode(.copy)
        Context.interpolationQuality = .high
        for Index in 0 ..< Layout.Count
        {
            let Source = (Index < Regions.count ? Regions[Index] : nil) ?? Background
            let Target = Layout.Rect(Index, Width: Background.width, Height: Background.height)
            let Part = Layout.Rect(Index, Width: Source.width, Height: Source.height)
            guard let Piece = Source.cropping(to: Part) else
            {
                return nil
            }
            // Core Graphics counts up from the bottom.
            let Placed = CGRect(x: Target.minX, y: CGFloat(Background.height) - Target.maxY, width: Target.width, height: Target.height)
            Context.saveGState()
            Context.clip(to: Placed)
            Context.draw(Piece, in: Placed)
            Context.restoreGState()
        }
        return Context.makeImage()
    }

    /// `Compose`, run off the main thread.
    @concurrent static func ComposeAsync(Background: CGImage, Layout: SplitLayouts, Regions: [CGImage?]) async -> CGImage?
    {
        Compose(Background: Background, Layout: Layout, Regions: Regions)
    }
}
