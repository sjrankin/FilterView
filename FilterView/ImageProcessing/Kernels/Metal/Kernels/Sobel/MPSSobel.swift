//
//  MPSSobel.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/30/26.
//

import Foundation
import CoreGraphics
import MetalPerformanceShaders

/// Edge detection using Metal Performance Shaders `MPSImageSobel`.
struct MPSSobel: ImageFilter
{
    static let FilterName = "MPS Sobel"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        return try await MetalProcessor.Shared.RunMPS(On: Input)
        {
            Device, Buffer, Source, Destination in
            MPSImageSobel(device: Device).encode(commandBuffer: Buffer, sourceTexture: Source, destinationTexture: Destination)
        }
    }
}
