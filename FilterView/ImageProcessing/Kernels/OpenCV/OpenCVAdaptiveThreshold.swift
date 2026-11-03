//
//  OpenCVAdaptiveThreshold.swift
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

/// Adaptive threshold with OpenCV: each pixel becomes black or white by comparing it with the average brightness of the pixels around it,
/// so it works on images that are lit unevenly.
struct OpenCVAdaptiveThreshold: ImageFilter
{
    static let FilterName = "OpenCV Adaptive Threshold"

    var FilterType: ImageFilterTypes
    {
        .OpenCV
    }

    /// Makes the image black and white.
    /// - Parameter Options: Missing or unreadable values use the defaults.
    ///   - "BLOCK": Size in pixels of the area compared with, 3 to 101. Made odd. Default 11.
    ///   - "C": Subtracted from the average before comparing. A pixel must be brighter than the average minus `C` to be white. -50 to 50,
    ///   default 2.
    ///   - "METHOD": "MEAN" (default) averages the area evenly, "GAUSSIAN" counts the pixels near the middle more.
    ///   - "INVERT": `true` makes the pixels that would be white black, and the reverse. Default `false`.
    ///   The alpha of each pixel is kept.
    @concurrent nonisolated func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let Block = min(OpenCVImage.OddSize(FilterOptionValues.Number(Options, "BLOCK", Default: 11), Minimum: 3), 101)
        let Offset = min(max(FilterOptionValues.Number(Options, "C", Default: 2), -50), 50)
        let Method: AdaptiveThresholdTypes = FilterOptionValues.Text(Options, "METHOD", Default: "MEAN") == "GAUSSIAN" ?
                                             .ADAPTIVE_THRESH_GAUSSIAN_C : .ADAPTIVE_THRESH_MEAN_C
        let Type: ThresholdTypes = FilterOptionValues.Flag(Options, "INVERT") ? .THRESH_BINARY_INV : .THRESH_BINARY
        return try OpenCVImage.Process(Input, .Gray)
        {
            Gray in
            let Result = Mat()
            Imgproc.adaptiveThreshold(src: Gray, dst: Result, maxValue: 255, adaptiveMethod: Method, thresholdType: Type,
                                      blockSize: Block, C: Offset)
            return Result
        }
    }
}
#endif
