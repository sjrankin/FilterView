//
//  ConditionalInvert.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
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

/// Inverts the colors of an image using the `InvertColor` Metal kernel.
struct ConditionalMetalInvert: ImageFilter
{
    static let FilterName = "Channel Invert"
    
    var FilterType: ImageFilterTypes
    {
        .Metal
    }
    
    /// Invert channels in the colors of the passed image. The caller determines which channels to invert.
    /// - Parameter Input: The image to process.
    /// - Options: Dictionary of `[String: Any]` with the recognized keys in the Notes.
    /// - Returns: Processed image.
    /// - Throws: Throws exceptions on error.
    /// - Note: The caller sends  a set of channels in the `Options` dictionary. Only the keys of the dictionary are
    /// used in this filter. If the `Options` dictionary does not contain exactly one value, the original image will be returned
    /// with no processing. Channel name (keys) are listed below. These are also defineded in the `Channels` enum in this
    /// file and the caller is strongly suggested to use that enum when calling this function.
    ///   - "RED": Invert the red channel.
    ///   - "GREEN": Invert the green channel.
    ///   - "BLUE": Invert the blue channel.
    ///   - "REDGREEN": Invert the red and green channels.
    ///   - "REDBLUE": Invert the red and blue channels.
    ///   - "GREENBLUE": Invert the green and blue channels.
    /// - Note: If there are no recognized channels in `Options`, the original image will be returned unchanged.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]?) async throws -> CGImage
    {
        guard let Options = Options,
              Options.count == 1 else
        {
            return Input
        }
        guard let Channel = Options.keys.first else
        {
            return Input
        }
        switch Channel
        {
            case Channels.Red.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "InvertColorR", On: Input)
                
            case Channels.Green.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "InvertColorG", On: Input)
                
            case Channels.Blue.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "InvertColorB", On: Input)
                
            case Channels.RedGreen.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "InvertColorRG", On: Input)
                
            case Channels.RedBlue.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "InvertColorRB", On: Input)
                
            case Channels.GreenBlue.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "InvertColorGB", On: Input)
                
            default:
                
                return Input
        }
    }
}

/// Channels and channel combinations.
enum Channels: String, CaseIterable
{
    /// Red channel.
    case Red = "RED"
    /// Green channel.
    case Green = "GREEN"
    /// Blue channel.
    case Blue = "BLUE"
    /// Red and Green channel.
    case RedGreen = "REDGREEN"
    /// Red and blue channel.
    case RedBlue = "REDBLUE"
    /// Green and blue channel.
    case GreenBlue = "GREENBLUE"
}
