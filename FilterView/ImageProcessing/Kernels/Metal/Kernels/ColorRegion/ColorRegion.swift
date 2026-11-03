//
//  ColorRegion.swift
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

/// Changes how much color the pixels inside a circle, oval, square, or rectangle have, from fully gray to the pixel's own color. The region
/// is worked out the same way as for `AlphaShape` (see `RegionOptions`).
struct ColorRegion: ImageFilter
{
    static let FilterName = "ColorRegion"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    /// Changes the color level inside the region. Pixels outside it are left alone.
    /// - Parameter Input: The image to process.
    /// - Parameter Options: The region's options, which `RegionOptions` describes, and these. Missing or unreadable values use the
    /// defaults.
    ///   - "MODE": `SET` (default) gives every pixel in the region the color level "LEVEL". `FADEOUT` goes from full color at the edge of the
    ///   region to gray at its center.
    ///   - "LEVEL": The color level `SET` uses, 0.0 to 1.0. 0 is fully gray, 1 is the pixel's own color, and a level between them is that
    ///   share of the way from gray to color. Default is 0.
    ///   - "INVERT": `true` keeps the middle and changes the surroundings. `SET` then sets the level of everything outside the region and
    ///   leaves the inside alone; `FADEOUT` goes from full color at the center to gray at the edge, with everything outside it gray.
    ///   Default is `false`.
    /// - Returns: Processed image, the same size, with the same alpha.
    /// - Throws: Throws exceptions on error.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]?) async throws -> CGImage
    {
        let Region = RegionOptions(Options: Options, Image: Input, ValueKey: "LEVEL")
        return try await MetalProcessor.Shared.Run(Kernel: "ColorRegion", On: Input, Parameters: Region.Parameters)
    }
}
