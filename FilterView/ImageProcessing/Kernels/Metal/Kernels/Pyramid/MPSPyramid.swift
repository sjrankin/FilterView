//
//  MPSPyramid.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/30/26.
//

import Foundation
import CoreGraphics
import MetalPerformanceShaders

/// Builds a Gaussian image pyramid with Metal Performance Shaders `MPSImageGaussianPyramid` (the concrete
/// `MPSImagePyramid`) and returns one level of it. Each level is half the size of the one before, so the result is smaller
/// than the input.
struct MPSPyramid: ImageFilter
{
    static let FilterName = "MPS Pyramid"

    var FilterType: ImageFilterTypes
    {
        .Metal
    }

    /// Builds the pyramid and returns one level of it.
    /// - Parameter Input: The image to process.
    /// - Parameter Options: Dictionary with at most one key (the value is ignored).
    ///   - "LEVEL1": Half size.
    ///   - "LEVEL2": Quarter size.
    ///   - "LEVEL3": One-eighth size.
    ///   - "LEVEL4": One-sixteenth size.
    /// If no recognized key is present, level 1 is returned.
    /// - Returns: The pyramid level.
    /// - Throws: `FilterException` if the image is too small for the level.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        var Level = 1
        for Candidate in 1 ... 4
        {
            if Options?["LEVEL\(Candidate)"] != nil
            {
                Level = Candidate
            }
        }
        // Blurring pulls in zeros past the image border, which would leave a ring of partly transparent pixels.
        return try await MetalProcessor.Shared.RunMPS(On: Input, ResultLevel: Level, Opaque: true, KeepSourceFormat: true)
        {
            Device, Buffer, Source, Destination in
            // The pyramid is built in place: level 0 of the mipmapped texture holds the image and MPS fills the rest.
            guard let Blit = Buffer.makeBlitCommandEncoder() else
            {
                throw FilterException(Message: "Metal setup failed")
            }
            Blit.copy(from: Source,
                      sourceSlice: 0,
                      sourceLevel: 0,
                      sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                      sourceSize: MTLSize(width: Source.width, height: Source.height, depth: 1),
                      to: Destination,
                      destinationSlice: 0,
                      destinationLevel: 0,
                      destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
            Blit.endEncoding()
            var Pyramid = Destination
            guard MPSImageGaussianPyramid(device: Device).encode(commandBuffer: Buffer, inPlaceTexture: &Pyramid, fallbackCopyAllocator: nil) else
            {
                throw FilterException(Message: "Could not build the image pyramid in place")
            }
        }
    }
}
