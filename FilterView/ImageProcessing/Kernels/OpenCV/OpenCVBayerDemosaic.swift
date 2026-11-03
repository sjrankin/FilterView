//
//  OpenCVBayerDemosaic.swift
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

/// Bayer demosaicing with OpenCV, from `bayer_demosaic.py`. A raw sensor image has only one color per pixel, in a repeating 2 x 2 pattern
/// of red, green, and blue filters (such as the raw Curiosity MastCam images). This works out the other two colors of each pixel from its
/// neighbors, making a full color image.
struct OpenCVBayerDemosaic: ImageFilter
{
    static let FilterName = "OpenCV Bayer Demosaic"

    var FilterType: ImageFilterTypes
    {
        .OpenCV
    }

    /// Demosaics the image. The image is read as one gray value per pixel, so it should be the raw image, not a color one.
    /// - Parameter Options: Missing or unreadable values use the defaults.
    ///   - "PATTERN": "BGGR" (default), "RGGB", "GRBG", or "GBRG". The names and the OpenCV conversions they use are the script's, which
    ///   confirmed "BGGR" for the Curiosity MastCam. OpenCV names its conversions differently from the order the filters sit on the
    ///   sensor: its "BG" conversion, used for "BGGR" here, is the one OpenCV itself also calls RGGB. If the colors come out wrong
    ///   (red and blue swapped, or a checkerboard), try another pattern.
    ///   - "VNG": `true` uses the slower Variable Number of Gradients method, which has fewer color fringes at edges. Default `false`.
    ///   The alpha of each pixel is kept.
    @concurrent nonisolated func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let UsesVNG = FilterOptionValues.Flag(Options, "VNG")
        let Code: ColorConversionCodes
        switch FilterOptionValues.Text(Options, "PATTERN", Default: "BGGR")
        {
            case "RGGB":
                Code = UsesVNG ? .COLOR_BayerRG2BGR_VNG : .COLOR_BayerRG2BGR

            case "GRBG":
                Code = UsesVNG ? .COLOR_BayerGR2BGR_VNG : .COLOR_BayerGR2BGR

            case "GBRG":
                Code = UsesVNG ? .COLOR_BayerGB2BGR_VNG : .COLOR_BayerGB2BGR

            default:
                Code = UsesVNG ? .COLOR_BayerBG2BGR_VNG : .COLOR_BayerBG2BGR
        }
        return try OpenCVImage.Process(Input, .Gray)
        {
            Raw in
            let Blue = Mat()
            Imgproc.cvtColor(src: Raw, dst: Blue, code: Code)
            // The conversion makes blue, green, red. The image is red, green, blue.
            let Result = Mat()
            Imgproc.cvtColor(src: Blue, dst: Result, code: .COLOR_BGR2RGB)
            return Result
        }
    }
}
#endif
