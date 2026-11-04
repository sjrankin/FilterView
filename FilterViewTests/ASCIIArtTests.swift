//
//  ASCIIArtTests.swift
//  FilterViewTests
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

import Testing
import Foundation
import CoreGraphics
import CoreText
@testable import FilterView

@MainActor
struct ASCIIArtTests
{
    /// A 96 x 96 image of one gray level (0 black to 1 white) with the given alpha.
    private func Solid(_ Gray: CGFloat, Alpha: CGFloat = 1) -> CGImage
    {
        let Context = CGContext(data: nil, width: 96, height: 96, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.setFillColor(CGColor(red: Gray, green: Gray, blue: Gray, alpha: Alpha))
        Context.fill(CGRect(x: 0, y: 0, width: 96, height: 96))
        return Context.makeImage()!
    }

    /// Every pixel of an image as premultiplied red, green, blue, alpha.
    private func Pixels(_ Image: CGImage) -> [[Int]]
    {
        let Context = CGContext(data: nil, width: Image.width, height: Image.height, bitsPerComponent: 8, bytesPerRow: Image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.draw(Image, in: CGRect(x: 0, y: 0, width: Image.width, height: Image.height))
        let Bytes = Context.data!.assumingMemoryBound(to: UInt8.self)
        return (0 ..< Image.width * Image.height).map
        {
            [Int(Bytes[$0 * 4]), Int(Bytes[$0 * 4 + 1]), Int(Bytes[$0 * 4 + 2]), Int(Bytes[$0 * 4 + 3])]
        }
    }

    /// How dark an image is, 0.0 (all white) to 1.0 (all black).
    private func Darkness(_ Image: CGImage) -> Double
    {
        let All = Pixels(Image)
        return All.reduce(0.0){$0 + Double(255 - $1[0])} / Double(All.count * 255)
    }

    @Test func RampIsOrderedByInkAndStartsWithTheSpace() throws
    {
        let Ramp = ASCIIRamp(FontName: "Menlo-Regular", Size: 10, Set: .ASCII)
        #expect(Ramp.Characters.first == 0x20)
        #expect(Ramp.Coverage.first == 0)
        #expect(Ramp.Coverage.last == 1)
        #expect(Ramp.Coverage == Ramp.Coverage.sorted())
        #expect(Ramp.Characters.count > 60)
        #expect(Ramp.Levels.count == 256)
        #expect(Ramp.Levels[0] == 0x20)
        // Dense characters, not the space, are at the other end.
        #expect(Ramp.Levels[255] != 0x20)
        #expect(Ramp.CellWidth > 0 && Ramp.CellHeight > Ramp.CellWidth)
    }

    @Test func ExtendedSetHasMoreCharactersThanASCII() throws
    {
        let Plain = ASCIIRamp(FontName: "Menlo-Regular", Size: 10, Set: .ASCII)
        let Extended = ASCIIRamp(FontName: "Menlo-Regular", Size: 10, Set: .Extended)
        #expect(Extended.Characters.count > Plain.Characters.count)
        #expect(Extended.Characters.contains(0x2588))
    }

    @Test func FontNamesCanBePostScriptFullOrFamilyNames() throws
    {
        for Name in ["Menlo-Regular", "Menlo", "menlo regular", "Courier"]
        {
            let Font = ASCIIRamp.MonospacedFont(named: Name, size: 12)
            #expect(CTFontGetSymbolicTraits(Font).contains(.traitMonoSpace))
        }
        #expect(CTFontCopyFamilyName(ASCIIRamp.MonospacedFont(named: "Courier", size: 12)) as String == "Courier")
    }

    @Test func MissingOrProportionalFontsGiveMenlo() throws
    {
        for Name in ["NoSuchFontAnywhere", "Helvetica", "", "   "]
        {
            let Font = ASCIIRamp.MonospacedFont(named: Name, size: 12)
            #expect(CTFontCopyPostScriptName(Font) as String == "Menlo-Regular")
        }
    }

    @Test func IsRegisteredAsACPUFilterAndInTheTree() throws
    {
        let Server = FilterServer()
        #expect(Server.GetFilter(ASCIIArt.FilterName)?.FilterType == .CPU)
        let Leaves = try FilterTreeLoader.Load(Resource: "FilterTree").Leaves()
        let Entry = try #require(Leaves.first{$0.Filter == ASCIIArt.FilterName})
        #expect(Set(Entry.Parameters?.map{$0.Key} ?? []) == ["FONT", "FONTSIZE", "CHARSET", "DENSITY", "INVERT", "BACKGROUND", "TEXTCOLOR"])
        // White background and black text are the defaults.
        #expect(Entry.Parameters?.first{$0.Key == "BACKGROUND"}?.Default == "FFFFFFFF")
        #expect(Entry.Parameters?.first{$0.Key == "TEXTCOLOR"}?.Default == "000000FF")
    }

    @Test func OutputIsAboutTheSizeOfTheInput() async throws
    {
        let Result = try await FilterServer().Run(Filter: ASCIIArt.FilterName, With: Solid(0.5), nil)
        // Whole characters only, so it can be a little smaller, but never bigger by more than rounding up.
        #expect(Result.width >= 96 - 8 && Result.width <= 97)
        #expect(Result.height >= 96 - 16 && Result.height <= 97)
    }

    @Test func WhiteImageIsAllBackgroundAndBlackImageHasMostInk() async throws
    {
        let Server = FilterServer()
        let White = try await Server.Run(Filter: ASCIIArt.FilterName, With: Solid(1), nil)
        let Gray = try await Server.Run(Filter: ASCIIArt.FilterName, With: Solid(0.5), nil)
        let Black = try await Server.Run(Filter: ASCIIArt.FilterName, With: Solid(0), nil)
        #expect(Pixels(White).allSatisfy{$0 == [255, 255, 255, 255]})
        #expect(Darkness(White) == 0)
        #expect(Darkness(Gray) > 0.02)
        #expect(Darkness(Black) > Darkness(Gray))
    }

    @Test func InvertSwapsWhichPartsGetInk() async throws
    {
        let Server = FilterServer()
        let Plain = try await Server.Run(Filter: ASCIIArt.FilterName, With: Solid(1), nil)
        let Inverted = try await Server.Run(Filter: ASCIIArt.FilterName, With: Solid(1), ["INVERT": "true"])
        #expect(Darkness(Plain) == 0)
        #expect(Darkness(Inverted) > 0.02)
    }

    @Test func TextIsDrawnInTheTextColorOnTheBackgroundColor() async throws
    {
        // Red background, blue text, and a black image (so lots of ink): green is never present.
        let Options = ["BACKGROUND": "FF0000FF", "TEXTCOLOR": "0000FFFF"]
        let Result = try await FilterServer().Run(Filter: ASCIIArt.FilterName, With: Solid(0), Options)
        let All = Pixels(Result)
        #expect(All.allSatisfy{$0[1] == 0 && $0[3] == 255})
        #expect(All.contains{$0[2] > 200})
        #expect(All.contains{$0[0] > 200})
        // With no ink, the whole image is the background.
        let Blank = try await FilterServer().Run(Filter: ASCIIArt.FilterName, With: Solid(1), Options)
        #expect(Pixels(Blank).allSatisfy{$0 == [255, 0, 0, 255]})
    }

    @Test func LightTextOnADarkBackgroundPutsInkWhereTheImageIsBright() async throws
    {
        let Options = ["BACKGROUND": "000000FF", "TEXTCOLOR": "FFFFFFFF"]
        let Server = FilterServer()
        let Bright = try await Server.Run(Filter: ASCIIArt.FilterName, With: Solid(1), Options)
        let Dark = try await Server.Run(Filter: ASCIIArt.FilterName, With: Solid(0), Options)
        #expect(Pixels(Dark).allSatisfy{$0 == [0, 0, 0, 255]})
        #expect(Pixels(Bright).contains{$0[0] > 200})
    }

    @Test func TransparentPartsOfTheImageGetNoInk() async throws
    {
        let Result = try await FilterServer().Run(Filter: ASCIIArt.FilterName, With: Solid(0, Alpha: 0), nil)
        #expect(Darkness(Result) == 0)
    }

    @Test func DensityAddsOrRemovesInk() async throws
    {
        let Server = FilterServer()
        let Light = try await Server.Run(Filter: ASCIIArt.FilterName, With: Solid(0.5), ["DENSITY": "0.4"])
        let Heavy = try await Server.Run(Filter: ASCIIArt.FilterName, With: Solid(0.5), ["DENSITY": "2.5"])
        #expect(Darkness(Heavy) > Darkness(Light))
    }

    @Test func SmallerFontsGiveMoreCharactersOfDetail() async throws
    {
        // Half black, half white: a bigger font shows the same edge with fewer, larger characters, but both keep the sides apart.
        let Context = CGContext(data: nil, width: 96, height: 96, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        Context.fill(CGRect(x: 0, y: 0, width: 96, height: 96))
        Context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        Context.fill(CGRect(x: 0, y: 0, width: 48, height: 96))
        let Split = Context.makeImage()!
        for FontSize in ["6", "12"]
        {
            let Result = try await FilterServer().Run(Filter: ASCIIArt.FilterName, With: Split, ["FONTSIZE": FontSize])
            let All = Pixels(Result)
            let Width = Result.width
            let LeftInk = (0 ..< All.count).filter{$0 % Width < Width / 2 - 8 && All[$0][0] < 128}.count
            let RightInk = (0 ..< All.count).filter{$0 % Width > Width / 2 + 8 && All[$0][0] < 128}.count
            #expect(LeftInk > 0)
            #expect(RightInk == 0)
        }
    }

    @Test func ATinyFontOnAHugeImageIsRefusedNotSlow() async throws
    {
        let Context = CGContext(data: nil, width: 6000, height: 6000, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        await #expect(throws: FilterException.self)
        {
            _ = try await FilterServer().Run(Filter: ASCIIArt.FilterName, With: Context.makeImage()!, ["FONTSIZE": "3"])
        }
    }
}
