//
//  ColorScaleColor.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/1/26.
//

import Foundation
import CoreGraphics

/// Converts the image to red, green, blue, cyan, magenta, or yellow scale, showing the color, not grayscale.
struct ColorScaleColor: ImageFilter
{
    static let FilterName = "ColorScaleColor"
    
    var FilterType: ImageFilterTypes
    {
        .Metal
    }
    
    /// Converts the image to color scale image, eg, gray scale (mean channels), red scale (all channels take on the red channel value), green scale, etc.
    /// - Parameter Input: The image to process.
    /// - Options: Dictionary of `[String: Any]` with the recognized keys in the Notes.
    /// - Returns: Processed image.
    /// - Throws: Throws exceptions on error.
    /// - Note: The caller sends  a set of channels in the `Options` dictionary. Only the keys of the dictionary are
    /// used in this filter. If the `Options` dictionary does not contain exactly one value, the original image will be returned
    /// with no processing. Channel name (keys) are listed below. These are also defineded in the `ScaleChannelsInColors` enum in this
    /// file and the caller is strongly suggested to use that enum when calling this function.
    ///   - "RED": Use the red channel to populate the green and blue channels.
    ///   - "GREEN": Use the green channel to populate the green and blue channels.
    ///   - "BLUE": Use the blue channel to populate the red and green channels.
    ///   - "CYAN": Use the mean of green and blue channels to populate the all of the channels.
    ///   - "MAGENTA": Use the mean of red and blue channels to populate the all of the channels.
    ///   - "YELLOW": Use the mean of red and green channels to populate the all of the channels.
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
            case ScaleChannelsInColor.Red.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleRedColor", On: Input)
                
            case ScaleChannelsInColor.Green.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleGreenColor", On: Input)
                
            case ScaleChannelsInColor.Blue.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleBlueColor", On: Input)
                
            case ScaleChannelsInColor.Cyan.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleCyanColor", On: Input)
                
            case ScaleChannelsInColor.Magenta.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleMagentaColor", On: Input)
                
            case ScaleChannelsInColor.Yellow.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "ScaleYellowColor", On: Input)
                
            default:
                return Input
        }
    }
}

/// Channels and channel combinations.
enum ScaleChannelsInColor: String, CaseIterable
{
    case Red = "RED"
    case Green = "GREEN"
    case Blue = "BLUE"
    case Cyan = "CYAN"
    case Magenta = "MAGENTA"
    case Yellow = "YELLOW"
}
