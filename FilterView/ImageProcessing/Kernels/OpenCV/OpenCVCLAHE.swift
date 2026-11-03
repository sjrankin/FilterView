//
//  OpenCVCLAHE.swift
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

#if os(macOS)
import Foundation
import CoreGraphics
import opencv2

/// CLAHE (contrast limited adaptive histogram equalization) with OpenCV: evens out the contrast in each part of the image on its own, and
/// limits how much, so noise is not blown up. Only the lightness is changed, not the colors.
struct OpenCVCLAHE: ImageFilter
{
    static let FilterName = "OpenCV CLAHE"

    var FilterType: ImageFilterTypes
    {
        .OpenCV
    }

    /// Improves the contrast.
    /// - Parameter Options: Missing or unreadable values use the defaults.
    ///   - "CLIP": How much the contrast can be raised, 1 to 40. Default 2.
    ///   - "TILES": The image is divided into this many parts across and down, 2 to 16. Default 8.
    ///   The alpha of each pixel is kept.
    @concurrent nonisolated func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let Clip = min(max(FilterOptionValues.Number(Options, "CLIP", Default: 2), 1), 40)
        let Tiles = Int32(min(max(FilterOptionValues.Number(Options, "TILES", Default: 8).rounded(), 2), 16))
        return try OpenCVImage.Process(Input, .Color)
        {
            Colors in
            let Lab = Mat()
            Imgproc.cvtColor(src: Colors, dst: Lab, code: .COLOR_RGB2Lab)
            var Channels: [Mat] = []
            Core.split(m: Lab, mv: &Channels)
            let Lightness = Mat()
            Imgproc.createCLAHE(clipLimit: Clip, tileGridSize: Size2i(width: Tiles, height: Tiles)).apply(src: Channels[0], dst: Lightness)
            Channels[0] = Lightness
            let Merged = Mat()
            Core.merge(mv: Channels, dst: Merged)
            let Result = Mat()
            Imgproc.cvtColor(src: Merged, dst: Result, code: .COLOR_Lab2RGB)
            return Result
        }
    }
}
#endif
