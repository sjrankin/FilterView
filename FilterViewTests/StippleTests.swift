//
//  StippleTests.swift
//  FilterViewTests
//
//  Created by Claude/Stuart Rankin on 11/17/26.
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

import Testing
import Foundation
import CoreGraphics
@testable import FilterView

@MainActor
struct StippleTests
{
    /// An opaque, 100 x 100 image of one gray level, or a left half of one level and a right half of another.
    private func Source(Left: UInt8, Right: UInt8? = nil, Alpha: UInt8 = 255) -> CGImage
    {
        var Pixels = [UInt8]()
        for _ in 0 ..< 100
        {
            for X in 0 ..< 100
            {
                let Level = Int(X < 50 ? Left : (Right ?? Left)) * Int(Alpha) / 255
                Pixels.append(contentsOf: [UInt8(Level), UInt8(Level), UInt8(Level), Alpha])
            }
        }
        let Provider = CGDataProvider(data: Data(Pixels) as CFData)!
        return CGImage(width: 100, height: 100, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: Provider, decode: nil,
                       shouldInterpolate: false, intent: .defaultIntent)!
    }

    private func Bytes(_ Image: CGImage) -> [UInt8]
    {
        let Context = CGContext(data: nil, width: Image.width, height: Image.height, bitsPerComponent: 8, bytesPerRow: Image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.draw(Image, in: CGRect(x: 0, y: 0, width: Image.width, height: Image.height))
        return Array(UnsafeBufferPointer(start: Context.data!.assumingMemoryBound(to: UInt8.self), count: Image.width * Image.height * 4))
    }

    /// The share of pixels in columns `Columns` that are not the base color (red channel above half).
    private func DotShare(_ Image: CGImage, Columns: Range<Int>) -> Double
    {
        let Data = Bytes(Image)
        var Dots = 0
        var Total = 0
        for Y in 0 ..< Image.height
        {
            for X in Columns
            {
                Total += 1
                if Data[(Y * Image.width + X) * 4] > 127
                {
                    Dots += 1
                }
            }
        }
        return Double(Dots) / Double(Total)
    }

    private func Run(_ Options: [String: String], From Image: CGImage) async throws -> CGImage
    {
        try await FilterServer().Run(Filter: Stipple.FilterName, With: Image, Options)
    }

    @Test func BlackStaysBlackAndWhiteGetsTheFullDensity() async throws
    {
        let Result = try await Run(["DENSITY": "1"], From: Source(Left: 0, Right: 255))
        #expect(DotShare(Result, Columns: 0 ..< 50) == 0)
        #expect(DotShare(Result, Columns: 50 ..< 100) == 1)
    }

    @Test func BrighterRegionsGetMoreDots() async throws
    {
        // With 4 regions, 70 and 150 and 230 out of 255 are in regions 1, 2, and 3.
        let Dark = DotShare(try await Run(["BANDS": "4", "DENSITY": "0.9", "CURVE": "1", "TEXTURE": "0"], From: Source(Left: 70)), Columns: 0 ..< 100)
        let Mid = DotShare(try await Run(["BANDS": "4", "DENSITY": "0.9", "CURVE": "1", "TEXTURE": "0"], From: Source(Left: 150)), Columns: 0 ..< 100)
        let Light = DotShare(try await Run(["BANDS": "4", "DENSITY": "0.9", "CURVE": "1", "TEXTURE": "0"], From: Source(Left: 230)), Columns: 0 ..< 100)
        #expect(Dark < Mid && Mid < Light)
        // Region n of 4 gets the density of its middle brightness, (n + 0.5) / 4.
        #expect(abs(Dark - 0.9 * 0.375) < 0.04)
        #expect(abs(Mid - 0.9 * 0.625) < 0.04)
        #expect(abs(Light - 0.9 * 0.875) < 0.04)
    }

    @Test func FewRegionsStayCloseToTheSmoothResult() async throws
    {
        // Mid-gray (128) in two regions is treated as the middle of the lower half, 0.25. The smooth result is 0.5, and the old mapping was 0.
        let Smooth = DotShare(try await Run(["CURVE": "1", "TEXTURE": "0"], From: Source(Left: 128)), Columns: 0 ..< 100)
        let Two = DotShare(try await Run(["BANDS": "2", "CURVE": "1", "TEXTURE": "0"], From: Source(Left: 128)), Columns: 0 ..< 100)
        let Sixteen = DotShare(try await Run(["BANDS": "16", "CURVE": "1", "TEXTURE": "0"], From: Source(Left: 128)), Columns: 0 ..< 100)
        #expect(Two > 0.2)
        #expect(abs(Sixteen - Smooth) < 0.06)
    }

    @Test func SmoothModeFollowsEachPixelsBrightnessAndTheCurveThinsDots() async throws
    {
        // 128/255 is about 0.5 bright. A straight curve gives about half dots, an exponent of 2 about a quarter.
        let Straight = DotShare(try await Run(["CURVE": "1", "TEXTURE": "0"], From: Source(Left: 128)), Columns: 0 ..< 100)
        let Curved = DotShare(try await Run(["CURVE": "2", "TEXTURE": "0"], From: Source(Left: 128)), Columns: 0 ..< 100)
        #expect(abs(Straight - 0.5) < 0.04)
        #expect(abs(Curved - 0.25) < 0.04)
    }

    @Test func TextureMakesRowsDifferFromEachOther() async throws
    {
        let Data = Bytes(try await Run(["CURVE": "1", "TEXTURE": "1"], From: Source(Left: 128)))
        var Shares = [Double]()
        for Y in 0 ..< 100
        {
            var Dots = 0
            for X in 0 ..< 100 where Data[(Y * 100 + X) * 4] > 127
            {
                Dots += 1
            }
            Shares.append(Double(Dots) / 100.0)
        }
        #expect((Shares.max() ?? 0) - (Shares.min() ?? 0) > 0.2)
    }

    @Test func TheSameSeedGivesTheSameDotsAndANewSeedMovesThem() async throws
    {
        let Image = Source(Left: 200)
        let A = Bytes(try await Run(["SEED": "1"], From: Image))
        let B = Bytes(try await Run(["SEED": "1"], From: Image))
        let C = Bytes(try await Run(["SEED": "2"], From: Image))
        #expect(A == B)
        #expect(A != C)
    }

    @Test func DotsAreSquaresOfTheDotSize() async throws
    {
        let Data = Bytes(try await Run(["DOTSIZE": "4", "DENSITY": "0.5"], From: Source(Left: 255)))
        for CellY in 0 ..< 25
        {
            for CellX in 0 ..< 25
            {
                let First = Data[((CellY * 4) * 100 + CellX * 4) * 4]
                for Y in 0 ..< 4
                {
                    for X in 0 ..< 4
                    {
                        #expect(Data[((CellY * 4 + Y) * 100 + CellX * 4 + X) * 4] == First)
                    }
                }
            }
        }
    }

    @Test func ChosenColorsReplaceBlackAndWhite() async throws
    {
        let Result = Bytes(try await Run(["DENSITY": "0.5", "BASE": "0000FF", "DOT": "FFFF00"], From: Source(Left: 255)))
        var Seen = Set<[UInt8]>()
        for Index in stride(from: 0, to: Result.count, by: 4)
        {
            Seen.insert(Array(Result[Index ..< Index + 4]))
        }
        #expect(Seen == [[0, 0, 255, 255], [255, 255, 0, 255]])
    }

    @Test func AlphaIsKept() async throws
    {
        let Result = Bytes(try await Run(["DENSITY": "1"], From: Source(Left: 255, Alpha: 128)))
        #expect(Result[3] == 128)
        #expect(Result[0] == 128)
    }
}
