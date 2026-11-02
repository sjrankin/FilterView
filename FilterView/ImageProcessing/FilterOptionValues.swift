//
//  FilterOptionValues.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics

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
        let PercentX = min(max(Number(Options, "CENTERX", Default: 50), 0), 100)
        let PercentY = min(max(Number(Options, "CENTERY", Default: 50), 0), 100)
        return CGPoint(x: Double(Image.width) * PercentX / 100.0, y: Double(Image.height) * (100.0 - PercentY) / 100.0)
    }
}
