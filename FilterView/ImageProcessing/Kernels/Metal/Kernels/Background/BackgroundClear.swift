//
//  BackgroundClear.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics

/// Replaces a target color (and colors near it) with a replacement color, which may be transparent.
struct BackgroundClear: ImageFilter
{
    static let FilterName = "BackgroundClear"
    
    var FilterType: ImageFilterTypes
    {
        .Metal
    }
    
    /// Replaces every pixel whose color is within the tolerance of the target color with the replacement color.
    /// - Parameter Input: The image to process.
    /// - Parameter Options: Dictionary of `[String: Any]` with the recognized keys in the Notes. Missing or unreadable values
    /// use the defaults.
    /// - Returns: Processed image.
    /// - Throws: Throws exceptions on error.
    /// - Note: Colors are strings of hexadecimal digits, `RRGGBB` or `RRGGBBAA` (with or without a leading `#`). Colors
    /// without an alpha are opaque. Alpha is part of the comparison, so an opaque target does not match transparent pixels.
    ///   - "TARGET": The color to look for. Default is opaque white.
    ///   - "SOURCE": The color that replaces it. Default is fully transparent (`00000000`), which clears the background.
    ///   - "TOLERANCE": A normal value, 0.0 to 1.0. 0.0 matches only the exact target color and 1.0 matches every color.
    ///   Default is 0.1.
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]?) async throws -> CGImage
    {
        let Target = BackgroundClear.ParseColor(Options?["TARGET"] as? String) ?? [1, 1, 1, 1]
        let Replacement = BackgroundClear.ParseColor(Options?["SOURCE"] as? String) ?? [0, 0, 0, 0]
        var Tolerance = BackgroundClear.DefaultTolerance
        if let Text = Options?["TOLERANCE"] as? String,
           let Value = Float(Text)
        {
            Tolerance = min(max(Value, 0.0), 1.0)
        }
        return try await MetalProcessor.Shared.Run(Kernel: "BackgroundClear",
                                                   On: Input,
                                                   Parameters: Target + Replacement + [Tolerance])
    }
    
    /// Tolerance when none is given.
    static let DefaultTolerance: Float = 0.1
    
    /// Converts a hexadecimal color string to red, green, blue, and alpha values, each 0.0 to 1.0.
    /// - Parameter Text: `RRGGBB` or `RRGGBBAA`, with or without a leading `#`.
    /// - Returns: Four values, or `nil` if the text is missing or is not a color.
    static func ParseColor(_ Text: String?) -> [Float]?
    {
        guard var Digits = Text?.trimmingCharacters(in: .whitespaces) else
        {
            return nil
        }
        if Digits.hasPrefix("#")
        {
            Digits.removeFirst()
        }
        guard Digits.count == 6 || Digits.count == 8,
              let Value = UInt32(Digits, radix: 16) else
        {
            return nil
        }
        let Packed = Digits.count == 6 ? (Value << 8) | 0xFF : Value
        return [Float((Packed >> 24) & 0xFF) / 255.0,
                Float((Packed >> 16) & 0xFF) / 255.0,
                Float((Packed >> 8) & 0xFF) / 255.0,
                Float(Packed & 0xFF) / 255.0]
    }
}
