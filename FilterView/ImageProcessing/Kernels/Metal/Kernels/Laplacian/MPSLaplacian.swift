//
//  MPSLaplacian.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/30/26.
//

import Foundation
import CoreGraphics
import MetalPerformanceShaders

/// Second-derivative edge detection using Metal Performance Shaders `MPSImageLaplacian`.
struct MPSLaplacian: ImageFilter
{
    static let FilterName = "MPS Laplacian"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        // The kernel also runs on alpha, which is constant, so the result would be fully transparent without `Opaque`.
        return try await MetalProcessor.Shared.RunMPS(On: Input, Opaque: true)
        {
            Device, Buffer, Source, Destination in
            MPSImageLaplacian(device: Device).encode(commandBuffer: Buffer, sourceTexture: Source, destinationTexture: Destination)
        }
    }
}
