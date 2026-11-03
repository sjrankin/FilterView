//
//  CICannyEdgeDetector.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
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
import CoreImage
import CoreImage.CIFilterBuiltins

/// Finds edges with the Canny method. Options: `SIGMA` (blur applied first, default 1.6), `PERCEPTUAL` (`true` works in a perceptual color
/// space; default `false`), `HIGH` (upper threshold, default 0.05), `LOW` (lower threshold, default 0.02), and `PASSES` (hysteresis passes,
/// default 1).
class CICannyEdgeDetector: ImageFilter
{
    static let FilterName = "CI Canny Edge Detector"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.cannyEdgeDetector()
        filter.inputImage = ci
        filter.gaussianSigma = Float(FilterOptionValues.Number(Options, "SIGMA", Default: 1.6))
        filter.perceptual = FilterOptionValues.Flag(Options, "PERCEPTUAL")
        filter.thresholdHigh = Float(FilterOptionValues.Number(Options, "HIGH", Default: 0.05))
        filter.thresholdLow = Float(FilterOptionValues.Number(Options, "LOW", Default: 0.02))
        filter.hysteresisPasses = Int(FilterOptionValues.Number(Options, "PASSES", Default: 1).rounded())
        guard let Result = filter.outputImage?.cropped(to: ci.extent),
              let Final = ImageUtility.CIImageToCGImage(Result) else
        {
            throw FilterException(Message: "Error from CICannyEdgeDetector.")
        }
        return Final
    }
}
