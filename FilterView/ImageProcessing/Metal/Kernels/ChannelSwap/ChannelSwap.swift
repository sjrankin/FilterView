//
//  ChannelSwap.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

import Foundation
import CoreGraphics

/// Inverts the colors of an image using the `InvertColor` Metal kernel.
struct ChannelSwap: ImageFilter
{
    static let FilterName = "Channel Swap"
    
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
            case SwapChannels.RedBlue.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "SwapRB", On: Input)
                
            case SwapChannels.RedGreen.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "SwapRG", On: Input)
                
            case SwapChannels.GreenBlue.rawValue:
                return try await MetalProcessor.Shared.Run(Kernel: "SwapGB", On: Input)
                
            default:
                return Input
        }
    }
}

/// Channels and channel combinations.
enum SwapChannels: String, CaseIterable
{
    case RedGreen = "REDGREEN"
    case RedBlue = "REDBLUE"
    case GreenBlue = "GREENBLUE"
}
