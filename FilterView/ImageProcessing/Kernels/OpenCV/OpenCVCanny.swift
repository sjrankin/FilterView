//
//  OpenCVCanny.swift
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

/// Canny edge detection with OpenCV: the gradient is thinned to one-pixel edges and kept where it is strong, or where a weaker edge joins a
/// strong one.
struct OpenCVCanny: ImageFilter
{
    static let FilterName = "OpenCV Canny"

    var FilterType: ImageFilterTypes
    {
        .OpenCV
    }

    /// Finds the edges in the image.
    /// - Parameter Options: Missing or unreadable values use the defaults.
    ///   - "LOW": Gradient above this, but not above `HIGH`, is a weak edge, kept only where it joins a strong edge. 0 to 500, default 100.
    ///   - "HIGH": Gradient above this is a strong edge. 0 to 500, default 200. Never below `LOW`.
    ///   - "APERTURE": Size of the Sobel operator used, 3, 5, or 7. Default 3.
    ///   - "L2": `true` measures the gradient more exactly (but more slowly). Default `false`.
    ///   The result is white edges on black. The alpha of each pixel is kept.
    @concurrent nonisolated func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let Low = min(max(FilterOptionValues.Number(Options, "LOW", Default: 100), 0), 500)
        let High = max(min(max(FilterOptionValues.Number(Options, "HIGH", Default: 200), 0), 500), Low)
        let RequestedAperture = Int32(FilterOptionValues.Number(Options, "APERTURE", Default: 3))
        let Aperture: Int32 = [3, 5, 7].contains(RequestedAperture) ? RequestedAperture : 3
        let UsesL2 = FilterOptionValues.Flag(Options, "L2")
        return try OpenCVImage.Process(Input, .Gray)
        {
            Gray in
            let Edges = Mat()
            Imgproc.Canny(image: Gray, edges: Edges, threshold1: Low, threshold2: High, apertureSize: Aperture, L2gradient: UsesL2)
            return Edges
        }
    }
}
#endif
