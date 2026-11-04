//
//  ASCIIRamp.swift
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

/// A mono-spaced font and the characters it can draw, ordered from the one with the least ink in its cell to the one with the most. Used
/// by `ASCIIArt` to pick a character for each part of an image.
nonisolated struct ASCIIRamp
{
    /// Which characters are tried.
    enum CharacterSets
    {
        /// The printable ASCII characters.
        case ASCII
        /// The printable ASCII characters, the printable Latin-1 characters, and the block characters (shades, halves, and the full block).
        /// Only those the font has are used.
        case Extended
    }

    /// The font used when the one asked for is missing or is not mono-spaced.
    static let FallbackFontName = "Menlo-Regular"

    /// The font, at the size it will be drawn.
    let Font: CTFont

    /// Width of a character cell, in points.
    let CellWidth: CGFloat

    /// Height of a character cell (a line), in points.
    let CellHeight: CGFloat

    /// Distance from the top of a cell to the baseline, in points.
    let Baseline: CGFloat

    /// The characters, as UTF-16 values, lightest first. The first is the space.
    let Characters: [UniChar]

    /// How much of its cell each character covers with ink, in the same order as `Characters`. Scaled so the densest is 1.0 and the space
    /// is 0.0.
    let Coverage: [Double]

    /// A character for each of 256 levels of ink, 0 (none) to 255 (the most the font can put in a cell): the one whose `Coverage` is
    /// closest.
    let Levels: [UniChar]

    /// Finds a mono-spaced font and measures its characters.
    /// - Parameter FontName: The PostScript name, full name, or family name of a font. If there is no such font, or it is not mono-spaced,
    ///   `FallbackFontName` is used.
    /// - Parameter Size: Size of the font in points.
    /// - Parameter Set: The characters to try.
    init(FontName: String, Size: CGFloat, Set: CharacterSets)
    {
        let Chosen = ASCIIRamp.MonospacedFont(named: FontName, size: Size)
        let Width = CTFontGetAdvancesForGlyphs(Chosen, .horizontal, [ASCIIRamp.Glyph(Chosen, 0x4D) ?? 0], nil, 1)
        let Leading = CTFontGetLeading(Chosen)
        Font = Chosen
        CellWidth = max(CGFloat(Width), 1)
        CellHeight = max(CTFontGetAscent(Chosen) + CTFontGetDescent(Chosen) + Leading, 1)
        Baseline = CTFontGetAscent(Chosen) + Leading / 2

        // The characters are measured at a large size, so thin strokes are not lost to rounding.
        let Reference = CTFontCreateCopyWithAttributes(Chosen, 48, nil, nil)
        let ReferenceWidth = ASCIIRamp.Advance(Reference, ASCIIRamp.Glyph(Reference, 0x4D) ?? 0)
        let ReferenceLeading = CTFontGetLeading(Reference)
        let ReferenceHeight = CTFontGetAscent(Reference) + CTFontGetDescent(Reference) + ReferenceLeading
        let ReferenceDescent = CTFontGetDescent(Reference) + ReferenceLeading / 2
        var Measured: [(Character: UniChar, Coverage: Double)] = []
        for Code in ASCIIRamp.Candidates(Set)
        {
            guard let Glyph = ASCIIRamp.Glyph(Reference, Code),
                  abs(ASCIIRamp.Advance(Reference, Glyph) - ReferenceWidth) <= ReferenceWidth * 0.05 else
            {
                continue
            }
            let Ink = ASCIIRamp.Ink(Glyph, Reference, Width: Int(ceil(ReferenceWidth)), Height: Int(ceil(ReferenceHeight)),
                                    BaselineFromBottom: ReferenceDescent)
            Measured.append((Code, Ink))
        }
        // Stable for equal ink, so the earlier (ASCII) character stays first.
        let Ordered = Measured.enumerated().sorted
        {
            $0.element.Coverage != $1.element.Coverage ? $0.element.Coverage < $1.element.Coverage : $0.offset < $1.offset
        }.map{$0.element}
        let Densest = max(Ordered.last?.Coverage ?? 1, 0.0001)
        let Scaled = Ordered.map{$0.Coverage / Densest}
        Characters = Ordered.map{$0.Character}
        Coverage = Scaled
        var Chosen256: [UniChar] = []
        var Index = 0
        for Level in 0 ..< 256
        {
            let Wanted = Double(Level) / 255.0
            while Index + 1 < Scaled.count && abs(Scaled[Index + 1] - Wanted) <= abs(Scaled[Index] - Wanted)
            {
                Index += 1
            }
            Chosen256.append(Ordered.isEmpty ? 0x20 : Ordered[Index].Character)
        }
        Levels = Chosen256
    }

    /// The font for a name, or the fallback.
    /// - Parameter Name: PostScript, full, or family name, in any case.
    /// - Parameter Size: Size in points.
    /// - Returns: The named font if it exists and is mono-spaced, otherwise Menlo, otherwise Courier.
    static func MonospacedFont(named Name: String, size Size: CGFloat) -> CTFont
    {
        for Candidate in [Name, FallbackFontName, "Courier"]
        {
            let Wanted = Candidate.trimmingCharacters(in: .whitespaces)
            guard !Wanted.isEmpty else
            {
                continue
            }
            let Found = CTFontCreateWithName(Wanted as CFString, Size, nil)
            // CTFontCreateWithName gives a default font for a name it does not know, so the name has to be checked.
            let Names = [CTFontCopyPostScriptName(Found), CTFontCopyFullName(Found), CTFontCopyFamilyName(Found)] as [String]
            if Names.contains(where: {$0.compare(Wanted, options: .caseInsensitive) == .orderedSame}),
               CTFontGetSymbolicTraits(Found).contains(.traitMonoSpace)
            {
                return Found
            }
        }
        return CTFontCreateWithName("Courier" as CFString, Size, nil)
    }

    /// The characters to try, as UTF-16 values, with the plain ASCII ones first.
    private static func Candidates(_ Set: CharacterSets) -> [UniChar]
    {
        var Codes = Array(0x20 ... 0x7E).map{UniChar($0)}
        if Set == .Extended
        {
            Codes += (0xA1 ... 0xFF).filter{$0 != 0xAD}.map{UniChar($0)}
            // Upper half, lower half, left half, right half, light, medium, and dark shade, and the full block.
            Codes += [0x2580, 0x2584, 0x258C, 0x2590, 0x2591, 0x2592, 0x2593, 0x2588]
        }
        return Codes
    }

    /// The glyph a font has for a character, or `nil` if it has none.
    private static func Glyph(_ Font: CTFont, _ Code: UniChar) -> CGGlyph?
    {
        var Character = Code
        var Found: CGGlyph = 0
        return CTFontGetGlyphsForCharacters(Font, &Character, &Found, 1) ? Found : nil
    }

    /// How far a glyph moves the pen, in points.
    private static func Advance(_ Font: CTFont, _ Glyph: CGGlyph) -> CGFloat
    {
        var Used = Glyph
        return CGFloat(CTFontGetAdvancesForGlyphs(Font, .horizontal, &Used, nil, 1))
    }

    /// The fraction of a cell, 0.0 to 1.0, that a glyph covers with ink.
    private static func Ink(_ Glyph: CGGlyph, _ Font: CTFont, Width: Int, Height: Int, BaselineFromBottom: CGFloat) -> Double
    {
        guard Width > 0, Height > 0,
              let Context = CGContext(data: nil, width: Width, height: Height, bitsPerComponent: 8, bytesPerRow: Width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let Bytes = Context.data?.assumingMemoryBound(to: UInt8.self) else
        {
            return 0
        }
        Context.setFillColor(gray: 1, alpha: 1)
        Context.fill(CGRect(x: 0, y: 0, width: Width, height: Height))
        Context.setFillColor(gray: 0, alpha: 1)
        var Used = Glyph
        var Position = CGPoint(x: 0, y: BaselineFromBottom)
        CTFontDrawGlyphs(Font, &Used, &Position, 1, Context)
        var Total = 0
        for Index in 0 ..< Width * Height
        {
            Total += 255 - Int(Bytes[Index])
        }
        return Double(Total) / Double(Width * Height * 255)
    }
}
