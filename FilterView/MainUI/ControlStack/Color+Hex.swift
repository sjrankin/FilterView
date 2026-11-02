//
//  Color+Hex.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import SwiftUI

extension Color
{
    /// Makes a color from `RRGGBB` or `RRGGBBAA` hexadecimal text, as filter options store colors.
    /// - Returns: `nil` if the text is not a color.
    init?(Hex: String)
    {
        guard let Parts = BackgroundClear.ParseColor(Hex) else
        {
            return nil
        }
        self.init(.sRGB, red: Double(Parts[0]), green: Double(Parts[1]), blue: Double(Parts[2]), opacity: Double(Parts[3]))
    }

    /// The color as `RRGGBBAA` hexadecimal text.
    func HexString(in Environment: EnvironmentValues) -> String
    {
        let Resolved = resolve(in: Environment)
        return [Resolved.red, Resolved.green, Resolved.blue, Resolved.opacity].map
        {
            let Byte = Int((min(max($0, 0), 1) * 255).rounded())
            let Digits = String(Byte, radix: 16, uppercase: true)
            return Digits.count == 1 ? "0" + Digits : Digits
        }.joined()
    }
}
