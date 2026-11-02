//
//  ChannelSwap.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

import Foundation
import CoreGraphics

/// Swaps two color channels of an image using the `SwapRG`, `SwapRB`, and `SwapGB` Metal kernels.
struct ChannelSwap: ImageFilter
{
    static let FilterName = "Channel Swap"
    
    var FilterType: ImageFilterTypes
    {
        .Metal
    }
    
    /// Swaps two channels of the passed image.
    /// - Parameter Input: The image to process.
    /// - Options: Dictionary of `[String: Any]` with the recognized key in the Notes.
    /// - Returns: Processed image.
    /// - Throws: Throws exceptions on error.
    /// - Note: The channels to swap are the value of the `"CHANNELS"` key. The values are also defined in the `SwapChannels`
    /// enum in this file and the caller is strongly suggested to use that enum when calling this function.
    ///   - "REDGREEN": Swap the red and green channels.
    ///   - "REDBLUE": Swap the red and blue channels.
    ///   - "GREENBLUE": Swap the green and blue channels.
    /// - Note: If there is no recognized value, the original image will be returned unchanged.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]?) async throws -> CGImage
    {
        switch Options?[ChannelSwap.ChannelsKey] as? String
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
    
    /// Option key that holds the channels to swap.
    static let ChannelsKey = "CHANNELS"
}

/// Channels and channel combinations.
enum SwapChannels: String, CaseIterable
{
    case RedGreen = "REDGREEN"
    case RedBlue = "REDBLUE"
    case GreenBlue = "GREENBLUE"
}
