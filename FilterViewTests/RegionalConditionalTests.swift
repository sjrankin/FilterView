//
//  RegionalConditionalTests.swift
//  FilterViewTests
//
//  Created by Claude/Stuart Rankin on 11/23/26.
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
struct RegionalConditionalTests
{
    /// An opaque 20 x 10 image: the left half is `Left` gray, the right half `Right` gray.
    private func Source(Left: UInt8, Right: UInt8) -> CGImage
    {
        var Pixels = [UInt8]()
        for _ in 0 ..< 10
        {
            for X in 0 ..< 20
            {
                let Level = X < 10 ? Left : Right
                Pixels.append(contentsOf: [Level, Level, Level, 255])
            }
        }
        let Provider = CGDataProvider(data: Data(Pixels) as CFData)!
        return CGImage(width: 20, height: 10, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 80, space: CGColorSpaceCreateDeviceRGB(),
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

    /// The red value and alpha of the pixel at X, Y (row 0 is the top).
    private func Pixel(_ Data: [UInt8], _ X: Int, _ Y: Int) -> (Red: UInt8, Alpha: UInt8)
    {
        (Data[(Y * 20 + X) * 4], Data[(Y * 20 + X) * 4 + 3])
    }

    private func Options(_ Extra: [String: Any] = [:]) -> [String: Any]
    {
        var Result: [String: Any] = ["FILTER": "Metal Invert", "ATTRIBUTE": "BRIGHTNESS", "BANDS": "4", "COMPARE": "GREATER", "VALUE": "0.5"]
        Result.merge(Extra){_, New in New}
        return Result
    }

    @Test func SeparateBandsMakeSeparateRegions() throws
    {
        let Pixels = Bytes(Source(Left: 30, Right: 220))
        let Map = RegionFinder.Find(Pixels: Pixels, Width: 20, Height: 10, Attribute: .Brightness, Bands: 4)
        #expect(Map.Count == 2)
        #expect(Map.Labels[0] != Map.Labels[19])
        #expect(Map.Means.min()! < 0.2)
        #expect(Map.Means.max()! > 0.8)
    }

    @Test func SameBandApartMakesTwoRegions() throws
    {
        // Dark, bright, dark: the two dark parts do not touch.
        var Pixels = [UInt8]()
        for X in 0 ..< 3
        {
            let Level: UInt8 = X == 1 ? 240 : 10
            Pixels.append(contentsOf: [Level, Level, Level, 255])
        }
        let Map = RegionFinder.Find(Pixels: Pixels, Width: 3, Height: 1, Attribute: .Brightness, Bands: 4)
        #expect(Map.Count == 3)
    }

    @Test func AttributesAreMeasuredFromZeroToOne() throws
    {
        #expect(RegionAttributes.Hue.Value(Red: 1, Green: 0, Blue: 0) == 0)
        #expect(abs(RegionAttributes.Hue.Value(Red: 0, Green: 1, Blue: 0) - 1.0 / 3.0) < 0.001)
        #expect(abs(RegionAttributes.Hue.Value(Red: 0, Green: 0, Blue: 1) - 2.0 / 3.0) < 0.001)
        #expect(RegionAttributes.Saturation.Value(Red: 0.5, Green: 0.5, Blue: 0.5) == 0)
    }

    @Test func GreaterRunsTheSecondFilterOnBrightRegionsOnly() async throws
    {
        let Server = FilterServer()
        let Filter = Server.GetFilter(RegionalConditional.FilterName)!
        defer { withExtendedLifetime(Server) {} }
        let Result = Bytes(try await Filter.ProcessImage(Source(Left: 30, Right: 220), Options()))
        // The dark left half is untouched; the bright right half is inverted.
        #expect(Pixel(Result, 2, 5).Red == 30)
        #expect(abs(Int(Pixel(Result, 17, 5).Red) - 35) <= 1)
    }

    @Test func LessRunsTheSecondFilterOnDarkRegionsOnly() async throws
    {
        let Server = FilterServer()
        let Filter = Server.GetFilter(RegionalConditional.FilterName)!
        defer { withExtendedLifetime(Server) {} }
        let Result = Bytes(try await Filter.ProcessImage(Source(Left: 30, Right: 220), Options(["COMPARE": "LESS"])))
        #expect(abs(Int(Pixel(Result, 2, 5).Red) - 225) <= 1)
        #expect(Pixel(Result, 17, 5).Red == 220)
    }

    @Test func RemoveClearsPixelsThatDoNotPass() async throws
    {
        let Server = FilterServer()
        let Filter = Server.GetFilter(RegionalConditional.FilterName)!
        defer { withExtendedLifetime(Server) {} }
        let Result = Bytes(try await Filter.ProcessImage(Source(Left: 30, Right: 220), Options(["REMOVE": "true"])))
        #expect(Pixel(Result, 2, 5).Alpha == 0)
        #expect(Pixel(Result, 17, 5).Alpha == 255)
    }

    @Test func ValueAboveEveryRegionChangesNothing() async throws
    {
        let Server = FilterServer()
        let Filter = Server.GetFilter(RegionalConditional.FilterName)!
        defer { withExtendedLifetime(Server) {} }
        let Image = Source(Left: 30, Right: 220)
        let Result = Bytes(try await Filter.ProcessImage(Image, Options(["VALUE": "1"])))
        #expect(Result == Bytes(Image))
    }

    @Test func InnerOptionsReachTheSecondFilter() async throws
    {
        let Server = FilterServer()
        let Filter = Server.GetFilter(RegionalConditional.FilterName)!
        defer { withExtendedLifetime(Server) {} }
        let Result = Bytes(try await Filter.ProcessImage(Source(Left: 30, Right: 220),
                                                         Options(["INNER_MODE": "RED", "VALUE": "0"])))
        // Only the red channel is inverted, so the pixel is no longer gray.
        let Data = Result
        #expect(Data[2 * 4] != Data[2 * 4 + 1])
    }

    @Test func MissingOrSelfFilterThrows() async throws
    {
        let Server = FilterServer()
        let Filter = Server.GetFilter(RegionalConditional.FilterName)!
        defer { withExtendedLifetime(Server) {} }
        await #expect(throws: FilterException.self)
        {
            _ = try await Filter.ProcessImage(self.Source(Left: 30, Right: 220), nil)
        }
        await #expect(throws: FilterException.self)
        {
            _ = try await Filter.ProcessImage(self.Source(Left: 30, Right: 220), ["FILTER": RegionalConditional.FilterName])
        }
    }

    @Test func TreeEntryNamesRealFilters() throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        let Server = FilterServer()
        #expect(FilterTreeLoader.MissingFilters(in: Root, Server: Server).isEmpty)
        let Leaf = Root.Leaves().first{$0.Filter == RegionalConditional.FilterName}
        let Choices = Leaf?.Parameters?.first{$0.Key == "FILTER"}?.Choices ?? []
        #expect(!Choices.isEmpty)
        for Choice in Choices
        {
            #expect(Server.GetFilter(Choice.Value) != nil)
        }
        #expect(Server.GetFilter(RegionalConditional.FilterName)?.FilterType == .Conditional)
    }
}
