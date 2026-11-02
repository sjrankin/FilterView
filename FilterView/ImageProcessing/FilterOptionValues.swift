//
//  FilterOptionValues.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage

/// Reads values from the options dictionary handed to a filter. The options panel stores every value as text, but callers in code
/// may pass numbers, so both are accepted.
enum FilterOptionValues
{
    /// A number from the options.
    /// - Parameter Options: The options dictionary. May be `nil`.
    /// - Parameter Key: The key of the value.
    /// - Parameter Default: Returned if the key is missing or its value is not a number.
    static func Number(_ Options: [String: Any]?, _ Key: String, Default: Double) -> Double
    {
        switch Options?[Key]
        {
            case let Text as String:
                return Double(Text) ?? Default

            case let Value as Double:
                return Value

            case let Value as Float:
                return Double(Value)

            case let Value as Int:
                return Double(Value)

            default:
                return Default
        }
    }

    /// An angle from the options, given in degrees, as radians.
    static func Radians(_ Options: [String: Any]?, _ Key: String, DefaultDegrees: Double) -> Double
    {
        Number(Options, Key, Default: DefaultDegrees) * .pi / 180.0
    }

    /// True if the value is `true` (as text or a boolean).
    static func Flag(_ Options: [String: Any]?, _ Key: String) -> Bool
    {
        switch Options?[Key]
        {
            case let Text as String:
                return Text == "true"

            case let Value as Bool:
                return Value

            default:
                return false
        }
    }

    /// The center point for a filter, from the `"CENTERX"` and `"CENTERY"` options, which are percentages of the image width and
    /// height (default 50, the middle). Y is measured from the top of the image, as the image is shown; Core Image measures from
    /// the bottom, so it is turned over here.
    static func Center(_ Options: [String: Any]?, _ Image: CGImage) -> CGPoint
    {
        Point(Options, "CENTERX", "CENTERY", Image, DefaultX: 50, DefaultY: 50)
    }

    /// A point from two percentage options, a percent of the width and a percent of the height. Y is measured from the top of the image,
    /// as the image is shown; Core Image measures from the bottom, so it is turned over here.
    /// - Parameter DefaultX: Percent used if the X option is missing.
    /// - Parameter DefaultY: Percent used if the Y option is missing.
    static func Point(_ Options: [String: Any]?, _ KeyX: String, _ KeyY: String, _ Image: CGImage, DefaultX: Double, DefaultY: Double) -> CGPoint
    {
        let PercentX = min(max(Number(Options, KeyX, Default: DefaultX), 0), 100)
        let PercentY = min(max(Number(Options, KeyY, Default: DefaultY), 0), 100)
        return CGPoint(x: Double(Image.width) * PercentX / 100.0, y: Double(Image.height) * (100.0 - PercentY) / 100.0)
    }

    /// A Core Image color from the options. The option is hexadecimal text, as the color picker in the options panel stores it.
    /// - Parameter Default: Red, green, blue, and alpha used if the key is missing or its value is not a color.
    static func CoreImageColor(_ Options: [String: Any]?, _ Key: String, Default: [Float]) -> CIColor
    {
        let Parts = Color(Options, Key, Default: Default)
        return CIColor(red: CGFloat(Parts[0]), green: CGFloat(Parts[1]), blue: CGFloat(Parts[2]), alpha: CGFloat(Parts[3]))
    }

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

    /// A color from the options, as red, green, blue, and alpha values (each 0.0 to 1.0). The option is hexadecimal text, as the
    /// color picker in the options panel stores it.
    /// - Parameter Default: Returned if the key is missing or its value is not a color.
    static func Color(_ Options: [String: Any]?, _ Key: String, Default: [Float]) -> [Float]
    {
        ParseColor(Options?[Key] as? String) ?? Default
    }

    /// Text from the options.
    /// - Parameter Default: Returned if the key is missing or its value is empty.
    static func Text(_ Options: [String: Any]?, _ Key: String, Default: String) -> String
    {
        if let Value = Options?[Key] as? String,
           !Value.isEmpty
        {
            return Value
        }
        return Default
    }
}
