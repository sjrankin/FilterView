//
//  OpenCVBilateral.swift
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

/// Bilateral filter with OpenCV: smooths the image while keeping edges sharp, by averaging only the neighbors that are close in color as
/// well as close in place.
struct OpenCVBilateral: ImageFilter
{
    static let FilterName = "OpenCV Bilateral"

    var FilterType: ImageFilterTypes
    {
        .OpenCV
    }

    /// Smooths the image.
    /// - Parameter Options: Missing or unreadable values use the defaults.
    ///   - "DIAMETER": Size in pixels of the neighborhood, 1 to 25. Default 9. Large values are slow.
    ///   - "SIGMACOLOR": How different two colors can be and still be averaged, 1 to 250. Default 75.
    ///   - "SIGMASPACE": How far away a pixel can be and still count, 1 to 250. Default 75.
    ///   The alpha of each pixel is kept.
    @concurrent nonisolated func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let Diameter = Int32(min(max(FilterOptionValues.Number(Options, "DIAMETER", Default: 9).rounded(), 1), 25))
        let SigmaColor = min(max(FilterOptionValues.Number(Options, "SIGMACOLOR", Default: 75), 1), 250)
        let SigmaSpace = min(max(FilterOptionValues.Number(Options, "SIGMASPACE", Default: 75), 1), 250)
        return try OpenCVImage.Process(Input, .Color)
        {
            Colors in
            let Smoothed = Mat()
            Imgproc.bilateralFilter(src: Colors, dst: Smoothed, d: Diameter, sigmaColor: SigmaColor, sigmaSpace: SigmaSpace)
            return Smoothed
        }
    }
}
#endif
