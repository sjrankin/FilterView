//
//  OpenCVMorphology.swift
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

/// Morphological operations with OpenCV: erode, dilate, open, close, and the gradient and hat variants, on the colors of the image.
struct OpenCVMorphology: ImageFilter
{
    static let FilterName = "OpenCV Morphology"

    var FilterType: ImageFilterTypes
    {
        .OpenCV
    }

    /// Applies the operation.
    /// - Parameter Options: Missing or unreadable values use the defaults.
    ///   - "OPERATION": "ERODE", "DILATE" (default), "OPEN", "CLOSE", "GRADIENT", "TOPHAT", or "BLACKHAT".
    ///   - "SHAPE": Shape of the neighborhood: "RECT" (default), "ELLIPSE", or "CROSS".
    ///   - "SIZE": Width and height of the neighborhood in pixels, 1 to 51. Made odd. Default 3.
    ///   - "ITERATIONS": How many times the operation is applied, 1 to 10. Default 1.
    ///   The alpha of each pixel is kept.
    @concurrent nonisolated func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let Operation: MorphTypes
        switch FilterOptionValues.Text(Options, "OPERATION", Default: "DILATE")
        {
            case "ERODE":
                Operation = .MORPH_ERODE

            case "OPEN":
                Operation = .MORPH_OPEN

            case "CLOSE":
                Operation = .MORPH_CLOSE

            case "GRADIENT":
                Operation = .MORPH_GRADIENT

            case "TOPHAT":
                Operation = .MORPH_TOPHAT

            case "BLACKHAT":
                Operation = .MORPH_BLACKHAT

            default:
                Operation = .MORPH_DILATE
        }
        let Shape: MorphShapes
        switch FilterOptionValues.Text(Options, "SHAPE", Default: "RECT")
        {
            case "ELLIPSE":
                Shape = .MORPH_ELLIPSE

            case "CROSS":
                Shape = .MORPH_CROSS

            default:
                Shape = .MORPH_RECT
        }
        let Size = min(OpenCVImage.OddSize(FilterOptionValues.Number(Options, "SIZE", Default: 3)), 51)
        let Iterations = Int32(min(max(FilterOptionValues.Number(Options, "ITERATIONS", Default: 1).rounded(), 1), 10))
        return try OpenCVImage.Process(Input, .Color)
        {
            Colors in
            let Kernel = Imgproc.getStructuringElement(shape: Shape, ksize: Size2i(width: Size, height: Size))
            let Result = Mat()
            Imgproc.morphologyEx(src: Colors, dst: Result, op: Operation, kernel: Kernel, anchor: Point2i(x: -1, y: -1), iterations: Iterations)
            return Result
        }
    }
}
#endif
