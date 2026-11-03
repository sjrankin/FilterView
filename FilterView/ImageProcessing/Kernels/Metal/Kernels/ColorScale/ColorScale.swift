//
//  ColorScale.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/1/26.
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

/// Converts the image to gray, red, green, blue, cyan, magenta, or yellow scale.
struct ColorScale: ImageFilter
{
    static let FilterName = "ColorScale"
    
    var FilterType: ImageFilterTypes
    {
        .Metal
    }
    
    /// Converts the image to color scale image, eg, gray scale (mean channels), red scale (all channels take on the red channel value), green scale, etc.
    /// - Parameter Input: The image to process.
    /// - Options: Dictionary of `[String: Any]` with the recognized keys in the Notes.
    /// - Returns: Processed image.
    /// - Throws: Throws exceptions on error.
    /// - Note: The channel to scale on is the value of the `"CHANNEL"` key. The values are also defined in the `ScaleChannels`
    /// enum in this file and the caller is strongly suggested to use that enum when calling this function.
    ///   - "GRAY": Use the mean of the red, green, and blue channels to populate all of the channels.
    ///   - "RED": Use the red channel to populate the green and blue channels.
    ///   - "GREEN": Use the green channel to populate the red and blue channels.
    ///   - "BLUE": Use the blue channel to populate the red and green channels.
    ///   - "CYAN": Use the mean of green and blue channels to populate the all of the channels.
    ///   - "MAGENTA": Use the mean of red and blue channels to populate the all of the channels.
    ///   - "YELLOW": Use the mean of red and green channels to populate the all of the channels.
    /// - Note: If the `"COLOR"` key is `"true"`, the scale is shown in its color (by `ColorScaleColor`) instead of as pure gray. Gray
    /// has no color version, so `"COLOR"` does not apply to it.
    /// - Note: If there is no recognized channel in `Options`, the original image will be returned unchanged.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]?) async throws -> CGImage
    {
        guard let Channel = Options?[ColorScale.ChannelKey] as? String else
        {
            return Input
        }
        if Options?[ColorScale.ColorKey] as? String == "true",
           Channel != ScaleChannels.Gray.rawValue
        {
            return try await ColorScaleColor().ProcessImage(Input, [Channel: ""])
        }
        switch Channel
        {
            case ScaleChannels.Gray.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleGray", On: Input)
                
            case ScaleChannels.Red.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleRed", On: Input)
                
            case ScaleChannels.Green.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleGreen", On: Input)
                
            case ScaleChannels.Blue.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleBlue", On: Input)
                
            case ScaleChannels.Cyan.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleCyan", On: Input)
                
            case ScaleChannels.Magenta.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleMagenta", On: Input)
                
            case ScaleChannels.Yellow.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleYellow", On: Input)
                
            default:
                return Input
        }
    }
    
    /// Option key that holds the channel to scale on.
    static let ChannelKey = "CHANNEL"
    
    /// Option key for showing the scale in its color. The value is `true` or `false`.
    static let ColorKey = "COLOR"
}

/// Channels and channel combinations.
enum ScaleChannels: String, CaseIterable
{
    case Gray = "GRAY"
    case Red = "RED"
    case Green = "GREEN"
    case Blue = "BLUE"
    case Cyan = "CYAN"
    case Magenta = "MAGENTA"
    case Yellow = "YELLOW"
}
