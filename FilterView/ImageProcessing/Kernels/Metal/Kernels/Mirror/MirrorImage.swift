//
//  MirrorImage.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
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

/// Mirrors one half of an image onto the other half so the halves meet with no seam. Which half is copied is chosen
/// by the `"HALF"` value in `Options`, using the Metal kernel for that half.
struct MirrorImage: ImageFilter
{
    static let FilterName = "Mirror"
    
    var FilterType: ImageFilterTypes
    {
        .Metal
    }
    
    /// Mirrors one half of the image.
    /// - Parameter Input: The image to process.
    /// - Parameter Options: Dictionary whose `"HALF"` key holds one value from `MirroringOptions`. If it is missing or not
    /// recognized, the original image is returned.
    ///   - "TOPTOP": The top half is copied to the bottom half, upside down.
    ///   - "BOTTOMBOTTOM": The bottom half is copied to the top half, upside down.
    ///   - "LEFTLEFT": The left half is copied to the right half, flipped.
    ///   - "RIGHTRIGHT": The right half is copied to the left half, flipped.
    /// - Returns: The mirrored image.
    /// - Throws: Throws exceptions on error.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        guard let Key = Options?[MirrorImage.HalfKey] as? String else
        {
            return Input
        }
        switch Key
        {
            case MirroringOptions.TopTop.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "MirrorVerticalTT", On: Input)
                
            case MirroringOptions.BottomBottom.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "MirrorVerticalBB", On: Input)
                
            case MirroringOptions.LeftLeft.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "MirrorHorizontalLL", On: Input)
                
            case MirroringOptions.RightRight.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "MirrorHorizontalRR", On: Input)
                
            default:
                return Input
        }
    }
    
    /// Option key that holds the half to copy.
    static let HalfKey = "HALF"
}

enum MirroringOptions: String
{
    case TopTop = "TOPTOP"
    case BottomBottom = "BOTTOMBOTTOM"
    case LeftLeft = "LEFTLEFT"
    case RightRight = "RIGHTRIGHT"
}
