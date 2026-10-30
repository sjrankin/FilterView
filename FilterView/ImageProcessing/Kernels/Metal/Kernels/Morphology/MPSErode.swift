//
//  MPSErode.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/30/26.
//

import Foundation
import CoreGraphics
import MetalPerformanceShaders

/// Shrinks bright areas (each pixel becomes the minimum in its neighborhood) using Metal Performance Shaders
/// `MPSImageErode` with a flat square structuring element. The size comes from `Options`; see `MPSMorphologyOptions`.
struct MPSErode: ImageFilter
{
    static let FilterName = "MPS Erode"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        let Size = MPSMorphologyOptions.Size(From: Options)
        // All zeros is a flat element, so the result is a plain neighborhood minimum.
        let Element = [Float](repeating: 0, count: Size * Size)
        return try await MetalProcessor.Shared.RunMPS(On: Input)
        {
            Device, Buffer, Source, Destination in
            MPSImageErode(device: Device, kernelWidth: Size, kernelHeight: Size, values: Element)
                .encode(commandBuffer: Buffer, sourceTexture: Source, destinationTexture: Destination)
        }
    }
}
