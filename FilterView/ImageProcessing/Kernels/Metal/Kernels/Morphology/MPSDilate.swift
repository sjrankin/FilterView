//
//  MPSDilate.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/30/26.
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

/// Grows bright areas (each pixel becomes the maximum in its neighborhood) using Metal Performance Shaders
/// `MPSImageDilate` with a flat square structuring element. The size comes from `Options`; see `MPSMorphologyOptions`.
struct MPSDilate: ImageFilter
{
    static let FilterName = "MPS Dilate"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        let Size = MPSMorphologyOptions.Size(From: Options)
        // All zeros is a flat element, so the result is a plain neighborhood maximum.
        let Element = [Float](repeating: 0, count: Size * Size)
        return try await MetalProcessor.Shared.RunMPS(On: Input)
        {
            Device, Buffer, Source, Destination in
            MPSImageDilate(device: Device, kernelWidth: Size, kernelHeight: Size, values: Element)
                .encode(commandBuffer: Buffer, sourceTexture: Source, destinationTexture: Destination)
        }
    }
}
