//
//  MPSHistogramEqualization.swift
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
import Metal
import MetalPerformanceShaders

/// Spreads out the tonal range of an image using Metal Performance Shaders `MPSImageHistogram` and
/// `MPSImageHistogramEqualization`. Each color channel is equalized separately, so colors can shift.
struct MPSHistogramEqualization: ImageFilter
{
    static let FilterName = "MPS Histogram Equalization"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        return try await MetalProcessor.Shared.RunMPS(On: Input)
        {
            Device, Buffer, Source, Destination in
            var Info = MPSImageHistogramInfo(numberOfHistogramEntries: 256,
                                             histogramForAlpha: false,
                                             minPixelValue: SIMD4<Float>(0, 0, 0, 0),
                                             maxPixelValue: SIMD4<Float>(1, 1, 1, 1))
            let Histogram = MPSImageHistogram(device: Device, histogramInfo: &Info)
            let Equalizer = MPSImageHistogramEqualization(device: Device, histogramInfo: &Info)
            guard let Storage = Device.makeBuffer(length: Histogram.histogramSize(forSourceFormat: Source.pixelFormat),
                                                  options: .storageModePrivate) else
            {
                throw FilterException(Message: "Could not allocate the histogram buffer")
            }
            // Count the pixel values, build the equalization transform from the counts, then apply it.
            Histogram.encode(to: Buffer, sourceTexture: Source, histogram: Storage, histogramOffset: 0)
            Equalizer.encodeTransform(to: Buffer, sourceTexture: Source, histogram: Storage, histogramOffset: 0)
            Equalizer.encode(commandBuffer: Buffer, sourceTexture: Source, destinationTexture: Destination)
        }
    }
}
