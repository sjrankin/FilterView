//
//  ASCIIArt.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
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
import CoreText

/// Turns an image into ASCII art: the image is divided into cells the size of one character of a mono-spaced font, and each cell becomes the
/// character that has about as much ink as the cell has darkness (or brightness, if the text is lighter than the background). The text is
/// drawn into a new image of about the size of the original. Runs on the CPU.
nonisolated struct ASCIIArt: ImageFilter
{
    static let FilterName = "ASCII Art"

    var FilterType: ImageFilterTypes
    {
        .CPU
    }

    /// The largest number of characters made, to keep a tiny font on a huge image from taking forever.
    private static let MaximumCells = 2_000_000

    /// Makes the ASCII art.
    /// - Parameter Options: Missing or unreadable values use the defaults.
    ///   - "FONT": The PostScript, full, or family name of a mono-spaced font. Default "Menlo-Regular". A name that is not an installed font,
    ///   or is not of a mono-spaced one, gives Menlo.
    ///   - "FONTSIZE": Size of the font in points, 3 to 72. Default 8. The smaller it is, the more characters, and the more detail.
    ///   - "CHARSET": "ASCII" (default) uses the printable ASCII characters; "EXTENDED" also uses the Latin-1 and block characters that the
    ///   font has.
    ///   - "DENSITY": 0.2 to 3, default 1. Above 1 puts more ink in the picture, below 1 less.
    ///   - "INVERT": `true` swaps which parts of the image get the most ink. Default `false`.
    ///   - "BACKGROUND": Color of the background, default opaque white.
    ///   - "TEXTCOLOR": Color of the text, default opaque black.
    ///   Where the text is darker than the background, dark parts of the image get dense characters, as on paper; where it is lighter,
    ///   bright parts do. Transparent parts of the image get no ink.
    /// - Returns: The text as an image, as big as the whole characters that fit in the original, so slightly smaller than it.
    /// - Throws: `FilterException` if the image is empty or the font is so small there would be too many characters.
    @concurrent nonisolated func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        guard Input.width > 0, Input.height > 0 else
        {
            throw FilterException(Message: "Empty image passed to ASCII Art.")
        }
        let Size = min(max(FilterOptionValues.Number(Options, "FONTSIZE", Default: 8), 3), 72)
        let Set: ASCIIRamp.CharacterSets = FilterOptionValues.Text(Options, "CHARSET", Default: "ASCII") == "EXTENDED" ? .Extended : .ASCII
        let Density = min(max(FilterOptionValues.Number(Options, "DENSITY", Default: 1), 0.2), 3)
        let Inverted = FilterOptionValues.Flag(Options, "INVERT")
        let Background = FilterOptionValues.Color(Options, "BACKGROUND", Default: [1, 1, 1, 1])
        let Ink = FilterOptionValues.Color(Options, "TEXTCOLOR", Default: [0, 0, 0, 1])
        let Ramp = ASCIIRamp(FontName: FilterOptionValues.Text(Options, "FONT", Default: ASCIIRamp.FallbackFontName),
                             Size: CGFloat(Size), Set: Set)

        let Columns = max(Int(Double(Input.width) / Double(Ramp.CellWidth)), 1)
        let Rows = max(Int(Double(Input.height) / Double(Ramp.CellHeight)), 1)
        guard Columns * Rows <= ASCIIArt.MaximumCells else
        {
            throw FilterException(Message: "The font is too small for this image. Use a larger font size.")
        }
        let Cells = try CellValues(Input, Columns, Rows)
        // Dark text on a light background is drawn like ink on paper: the darker the part of the image, the more ink.
        let InkIsDarker = Luminance(Ink) < Luminance(Background)
        try Task.checkCancellation()

        var Lines: [String] = []
        Lines.reserveCapacity(Rows)
        for Row in 0 ..< Rows
        {
            var Characters: [UniChar] = []
            Characters.reserveCapacity(Columns)
            for Column in 0 ..< Columns
            {
                let Cell = Cells[Row * Columns + Column]
                var Target = InkIsDarker ? Cell.Alpha - Cell.Brightness : Cell.Brightness
                if Inverted
                {
                    Target = Cell.Alpha - Target
                }
                Target = pow(min(max(Target, 0), 1), 1.0 / Density)
                Characters.append(Ramp.Levels[Int((Target * 255).rounded())])
            }
            Lines.append(String(decoding: Characters, as: UTF16.self))
        }
        return try Draw(Lines, Ramp, Columns, Rows, Background, Ink)
    }

    /// How bright (0.0 to 1.0) and how opaque each cell of the image is, row by row from the top. Brightness is multiplied by alpha, as the
    /// image has its colors premultiplied.
    private func CellValues(_ Image: CGImage, _ Columns: Int, _ Rows: Int) throws -> [(Brightness: Double, Alpha: Double)]
    {
        guard let Space = CGColorSpace(name: CGColorSpace.sRGB),
              let Context = CGContext(data: nil, width: Columns, height: Rows, bitsPerComponent: 8, bytesPerRow: Columns * 4, space: Space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let Bytes = Context.data?.assumingMemoryBound(to: UInt8.self) else
        {
            throw FilterException(Message: "Cannot read the image for ASCII Art.")
        }
        // Drawing the whole image into one pixel per cell averages the pixels each cell covers.
        Context.interpolationQuality = .high
        Context.draw(Image, in: CGRect(x: 0, y: 0, width: Columns, height: Rows))
        var Result: [(Brightness: Double, Alpha: Double)] = []
        Result.reserveCapacity(Columns * Rows)
        for Cell in 0 ..< Columns * Rows
        {
            let Red = Double(Bytes[Cell * 4]) / 255.0
            let Green = Double(Bytes[Cell * 4 + 1]) / 255.0
            let Blue = Double(Bytes[Cell * 4 + 2]) / 255.0
            Result.append((0.2126 * Red + 0.7152 * Green + 0.0722 * Blue, Double(Bytes[Cell * 4 + 3]) / 255.0))
        }
        return Result
    }

    /// How bright a color is, 0.0 to 1.0.
    private func Luminance(_ Color: [Float]) -> Float
    {
        0.2126 * Color[0] + 0.7152 * Color[1] + 0.0722 * Color[2]
    }

    /// Draws the lines of text on the background.
    private func Draw(_ Lines: [String], _ Ramp: ASCIIRamp, _ Columns: Int, _ Rows: Int, _ Background: [Float], _ Ink: [Float]) throws -> CGImage
    {
        let Width = Int(ceil(CGFloat(Columns) * Ramp.CellWidth))
        let Height = Int(ceil(CGFloat(Rows) * Ramp.CellHeight))
        guard let Space = CGColorSpace(name: CGColorSpace.sRGB),
              let Context = CGContext(data: nil, width: Width, height: Height, bitsPerComponent: 8, bytesPerRow: 0, space: Space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let BackgroundColor = CGColor(colorSpace: Space, components: Background.map{CGFloat($0)}),
              let InkColor = CGColor(colorSpace: Space, components: Ink.map{CGFloat($0)}) else
        {
            throw FilterException(Message: "Cannot make the ASCII Art image.")
        }
        Context.setFillColor(BackgroundColor)
        Context.fill(CGRect(x: 0, y: 0, width: Width, height: Height))
        // Smoothing is the thickening that macOS does to dark text on light backgrounds. It would change how much ink a character has.
        Context.setShouldSmoothFonts(false)
        Context.setShouldAntialias(true)
        let Attributes = [kCTFontAttributeName: Ramp.Font, kCTForegroundColorAttributeName: InkColor] as CFDictionary
        for (Row, Text) in Lines.enumerated()
        {
            let Line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, Text as CFString, Attributes))
            // Core Graphics measures from the bottom; the rows run from the top.
            Context.textPosition = CGPoint(x: 0, y: CGFloat(Height) - CGFloat(Row) * Ramp.CellHeight - Ramp.Baseline)
            CTLineDraw(Line, Context)
        }
        guard let Made = Context.makeImage() else
        {
            throw FilterException(Message: "Cannot make the ASCII Art image.")
        }
        return Made
    }
}
