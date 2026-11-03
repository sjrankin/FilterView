//
//  ColorSwapTests.swift
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
@testable import FilterView

/// Color Swap is the tree entry for the `BackgroundClear` filter.
@MainActor
struct ColorSwapTests
{
    /// A row of pixels 0 to 5: opaque black, half-transparent black, fully transparent, opaque red, half-transparent dark gray, opaque white.
    /// The bytes are premultiplied, as the image stores them.
    private func Row() -> CGImage
    {
        let Pixels: [UInt8] = [0, 0, 0, 255,
                               0, 0, 0, 128,
                               0, 0, 0, 0,
                               255, 0, 0, 255,
                               20, 20, 20, 128,
                               255, 255, 255, 255]
        let Provider = CGDataProvider(data: Data(Pixels) as CFData)!
        return CGImage(width: 6, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 24, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: Provider, decode: nil,
                       shouldInterpolate: false, intent: .defaultIntent)!
    }

    /// The pixel at x, as straight red, green, blue, and alpha bytes.
    private func Pixel(_ Image: CGImage, _ X: Int) -> [Int]
    {
        let Context = CGContext(data: nil, width: Image.width, height: Image.height, bitsPerComponent: 8, bytesPerRow: Image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.draw(Image, in: CGRect(x: 0, y: 0, width: Image.width, height: Image.height))
        let Bytes = Context.data!.assumingMemoryBound(to: UInt8.self)
        return [Int(Bytes[X * 4]), Int(Bytes[X * 4 + 1]), Int(Bytes[X * 4 + 2]), Int(Bytes[X * 4 + 3])]
    }

    private func Run(_ Options: [String: String]) async throws -> CGImage
    {
        try await FilterServer().Run(Filter: BackgroundClear.FilterName, With: Row(), Options)
    }

    private let Yellow = ["TARGET": "000000FF", "SOURCE": "FFFF00FF", "TOLERANCE": "0.1"]

    @Test func AlphaCountsTowardsClosenessByDefault() async throws
    {
        let Result = try await Run(Yellow)
        // Opaque black is matched. Half-transparent black is not, as its alpha is far from the target's.
        #expect(Pixel(Result, 0) == [255, 255, 0, 255])
        #expect(Pixel(Result, 1)[0] == 0 && Pixel(Result, 1)[3] == 128)
        #expect(Pixel(Result, 2)[3] == 0)
    }

    @Test func IgnoringAlphaMatchesBlackWhateverItsTransparency() async throws
    {
        var Options = Yellow
        Options["IGNOREALPHA"] = "true"
        let Result = try await Run(Options)
        #expect(Pixel(Result, 0) == [255, 255, 0, 255])
        #expect(Pixel(Result, 1) == [255, 255, 0, 255])
    }

    @Test func ANearlyTransparentBlackIsStillMatchedWhenAlphaIsIgnored() async throws
    {
        // Alpha 128 with premultiplied color 20 is a straight gray of about 40, which is within a loose tolerance of black.
        var Options = Yellow
        Options["IGNOREALPHA"] = "true"
        Options["TOLERANCE"] = "0.2"
        let Result = try await Run(Options)
        #expect(Pixel(Result, 4) == [255, 255, 0, 255])
    }

    @Test func AFullyTransparentPixelHasNoColorAndIsLeftAlone() async throws
    {
        var Options = Yellow
        Options["IGNOREALPHA"] = "true"
        Options["TOLERANCE"] = "1"
        // Even matching every color, a pixel with no alpha is not changed.
        let Result = try await Run(Options)
        #expect(Pixel(Result, 2)[3] == 0)
        #expect(Pixel(Result, 0) == [255, 255, 0, 255])
    }

    @Test func OtherColorsAreStillLeftAloneWhenAlphaIsIgnored() async throws
    {
        var Options = Yellow
        Options["IGNOREALPHA"] = "true"
        let Result = try await Run(Options)
        #expect(Pixel(Result, 3) == [255, 0, 0, 255])
        #expect(Pixel(Result, 5) == [255, 255, 255, 255])
    }

    @Test func AHighToleranceWithAlphaCountedMatchesTheTransparentPixelsToo() async throws
    {
        // Raising the tolerance to catch half-transparent black also catches fully transparent pixels, which read as black with no alpha.
        // This is the surprise that ignoring alpha avoids.
        var Options = Yellow
        Options["TOLERANCE"] = "0.5"
        let Result = try await Run(Options)
        #expect(Pixel(Result, 2) == [255, 255, 0, 255])
        Options["IGNOREALPHA"] = "true"
        let Ignored = try await Run(Options)
        #expect(Pixel(Ignored, 2)[3] == 0)
        #expect(Pixel(Ignored, 1) == [255, 255, 0, 255])
    }

    /// True if two bytes are within 2 of each other, as premultiplying and rounding can be off by one.
    private func Near(_ A: [Int], _ B: [Int]) -> Bool
    {
        zip(A, B).allSatisfy{abs($0 - $1) <= 2}
    }

    @Test func KeepingAlphaReplacesOnlyTheColor() async throws
    {
        var Options = Yellow
        Options["IGNOREALPHA"] = "true"
        Options["KEEPALPHA"] = "true"
        let Result = try await Run(Options)
        // Opaque black becomes opaque yellow. Half-transparent black becomes half-transparent yellow: premultiplied, 128, 128, 0, 128.
        #expect(Pixel(Result, 0) == [255, 255, 0, 255])
        #expect(Near(Pixel(Result, 1), [128, 128, 0, 128]))
        // A fully transparent pixel is still not matched.
        #expect(Pixel(Result, 2)[3] == 0)
    }

    @Test func WithoutKeepingAlphaTheReplacementsAlphaIsUsed() async throws
    {
        var Options = Yellow
        Options["IGNOREALPHA"] = "true"
        let Result = try await Run(Options)
        #expect(Pixel(Result, 1) == [255, 255, 0, 255])
        // A replacement that is itself half-transparent gives half-transparent yellow whatever the pixel was.
        Options["SOURCE"] = "FFFF0080"
        let Faint = try await Run(Options)
        #expect(Near(Pixel(Faint, 0), [128, 128, 0, 128]))
        #expect(Near(Pixel(Faint, 1), [128, 128, 0, 128]))
    }

    @Test func KeepingAlphaIgnoresTheReplacementsAlpha() async throws
    {
        var Options = Yellow
        Options["IGNOREALPHA"] = "true"
        Options["KEEPALPHA"] = "true"
        Options["SOURCE"] = "FFFF0000"
        let Result = try await Run(Options)
        #expect(Pixel(Result, 0) == [255, 255, 0, 255])
        #expect(Near(Pixel(Result, 1), [128, 128, 0, 128]))
    }

    @Test func KeepingAlphaWorksWithAlphaCountedToo() async throws
    {
        // With a loose tolerance the transparent pixel is matched, but it keeps its alpha of 0, so it stays clear instead of turning yellow.
        var Options = Yellow
        Options["TOLERANCE"] = "0.5"
        Options["KEEPALPHA"] = "true"
        let Result = try await Run(Options)
        #expect(Pixel(Result, 2)[3] == 0)
        #expect(Pixel(Result, 0) == [255, 255, 0, 255])
    }

    @Test func TheTreeEntryHasTheSwitchOffByDefault() throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        let Entry = try #require(Root.Leaves().first{$0.Filter == BackgroundClear.FilterName})
        #expect(Entry.Name == "Color Swap")
        let Switch = try #require(Entry.Parameters?.first{$0.Key == "IGNOREALPHA"})
        #expect(Switch.Kind == .Toggle && Switch.Default == "false")
        let Keep = try #require(Entry.Parameters?.first{$0.Key == "KEEPALPHA"})
        #expect(Keep.Kind == .Toggle && Keep.Default == "false")
        #expect(Entry.Parameters?.map{$0.Key} == ["TARGET", "SOURCE", "TOLERANCE", "IGNOREALPHA", "KEEPALPHA"])
    }
}
