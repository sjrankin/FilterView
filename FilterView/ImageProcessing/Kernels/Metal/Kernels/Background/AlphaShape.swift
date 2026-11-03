//
//  AlphaShape.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
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

import Foundation
import CoreGraphics

/// Changes the alpha of the pixels inside a circle, oval, square, or rectangle. The region is worked out the same way as for `ColorRegion`
/// (see `RegionOptions`).
struct AlphaShape: ImageFilter
{
    static let FilterName = "AlphaShape"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    /// Changes the alpha inside the shape. Pixels outside it are left alone.
    /// - Parameter Input: The image to process.
    /// - Parameter Options: Dictionary of `[String: Any]` with the recognized keys in the Notes. Missing or unreadable values use the
    /// defaults.
    /// - Returns: Processed image.
    /// - Throws: Throws exceptions on error.
    /// - Note: The size of the shape is worked out as if the image went on forever, so a shape that goes past the edge of the image
    /// still has its effect spread over its whole size and only the part on the image shows.
    ///   - "CENTERX", "CENTERY": Where the middle of the shape is, as percentages of the width and height, with Y from the top.
    ///   Default is 50, 50, the middle of the image.
    ///   - "SHAPE": `CIRCLE` (default), `OVAL`, `SQUARE`, or `RECTANGLE`.
    ///   - "SIZE": The size of the hole, which is the length of the shape's long axis (the diameter of a circle, the side of a square), as a
    ///   percentage of the shorter side of the image. It may be more than 100. The alpha is worked out across the hole, so it follows
    ///   its size. Default is 50.
    ///   - "ASPECT": For an oval or rectangle, the length of the short axis as a percentage of the long axis, 1 to 100. Default is 50.
    ///   - "ANGLE": For an oval or rectangle, the direction of the long axis in degrees, clockwise from the horizontal. Default is 0.
    ///   - "MODE": `SET` (default) sets the alpha of every pixel in the shape to "ALPHA". `FADEOUT` goes from alpha 1.0 at the edge of
    ///   the shape to 0.0 at its center.
    ///   - "ALPHA": The alpha `SET` uses, 0.0 to 1.0. Default is 0.
    ///   - "INVERT": `true` keeps the middle and changes the surroundings. `SET` then sets the alpha of everything outside the shape and
    ///   leaves the inside alone; `FADEOUT` goes from opaque at the center to clear at the edge of the shape, with everything outside it
    ///   clear. Default is `false`.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]?) async throws -> CGImage
    {
        let Region = RegionOptions(Options: Options, Image: Input, ValueKey: "ALPHA")
        return try await MetalProcessor.Shared.Run(Kernel: "AlphaShape", On: Input, Parameters: Region.Parameters)
    }
}
