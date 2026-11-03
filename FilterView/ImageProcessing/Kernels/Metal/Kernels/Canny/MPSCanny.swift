//
//  MPSCanny.swift
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
import MetalPerformanceShaders

/// Canny edge detection using Metal Performance Shaders `MPSImageCanny`: a Gaussian blur, then the gradient, thinned to one-pixel edges,
/// kept where it is strong or where a weak edge joins a strong one.
struct MPSCanny: ImageFilter
{
    static let FilterName = "MPS Canny"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    /// Finds the edges in the image.
    /// - Parameter Options: Missing or unreadable values use the defaults.
    ///   - "SIGMA": How much the image is blurred first, as the standard deviation of a Gaussian, in pixels. More blur finds only the larger
    ///   edges. Default is 1.41, the square root of 2.
    ///   - "HIGH": Gradient above this, 0.0 to 1.0, is a strong edge. Default is 0.4.
    ///   - "LOW": Gradient above this, but not above `HIGH`, is a weak edge, kept only where it joins a strong edge. It cannot be above
    ///   `HIGH`; if it is it is made equal to it. Default is 0.2.
    ///   - "FAST": `true` (default) is the faster approximation, in which a strong edge can only reach so far along weak edges. `false` is the
    ///   full algorithm.
    ///   The image is made gray first (with the JPEG weights) and the result is white edges on black.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let Sigma = Float(max(FilterOptionValues.Number(Options, "SIGMA", Default: 2.0.squareRoot()), 0.1))
        let High = Float(min(max(FilterOptionValues.Number(Options, "HIGH", Default: 0.4), 0), 1))
        let Low = min(Float(min(max(FilterOptionValues.Number(Options, "LOW", Default: 0.2), 0), 1)), High)
        let UsesFastMode = Options?["FAST"] == nil ? true : FilterOptionValues.Flag(Options, "FAST")
        // The weights are the filter's default ones; it only accepts them together with a sigma.
        let Weights: [Float] = [0.299, 0.587, 0.114]
        return try await MetalProcessor.Shared.RunMPS(On: Input, Opaque: true, Monochrome: true)
        {
            Device, Buffer, Source, Destination in
            let Canny = MPSImageCanny(device: Device, linearToGrayScaleTransform: Weights, sigma: Sigma)
            Canny.highThreshold = High
            Canny.lowThreshold = Low
            Canny.useFastMode = UsesFastMode
            Canny.encode(commandBuffer: Buffer, sourceTexture: Source, destinationTexture: Destination)
        }
    }
}
