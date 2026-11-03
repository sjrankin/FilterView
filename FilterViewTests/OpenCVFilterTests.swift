//
//  OpenCVFilterTests.swift
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

#if os(macOS)
import Testing
import Foundation
import CoreGraphics
@testable import FilterView

@MainActor
struct OpenCVFilterTests
{
    /// A 64 x 64 image with a white square from 20 to 44 on black, all of it with the given alpha (0 to 1).
    private func Square(Alpha: CGFloat = 1) -> CGImage
    {
        let Context = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: Alpha))
        Context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        Context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: Alpha))
        Context.fill(CGRect(x: 20, y: 20, width: 24, height: 24))
        return Context.makeImage()!
    }

    private func Pixel(_ Image: CGImage, _ X: Int, _ Y: Int) -> [Int]
    {
        let Context = CGContext(data: nil, width: Image.width, height: Image.height, bitsPerComponent: 8, bytesPerRow: Image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.draw(Image, in: CGRect(x: 0, y: 0, width: Image.width, height: Image.height))
        let Bytes = Context.data!.assumingMemoryBound(to: UInt8.self)
        let Start = (Y * Image.width + X) * 4
        return [Int(Bytes[Start]), Int(Bytes[Start + 1]), Int(Bytes[Start + 2]), Int(Bytes[Start + 3])]
    }

    @Test func AllOpenCVFiltersAreRegisteredAndInTheTree() throws
    {
        let Server = FilterServer()
        let Names = [OpenCVBayerDemosaic.FilterName, OpenCVCanny.FilterName, OpenCVBilateral.FilterName, OpenCVCLAHE.FilterName,
                     OpenCVAdaptiveThreshold.FilterName, OpenCVMorphology.FilterName]
        for Name in Names
        {
            #expect(Server.GetFilter(Name) != nil)
            #expect(Server.GetFilter(Name)?.FilterType == .OpenCV)
        }
        let Tree = try FilterTreeLoader.Load(Resource: "FilterTree")
        let InTree = Tree.Leaves().compactMap{$0.Filter}
        for Name in Names
        {
            #expect(InTree.contains(Name))
        }
    }

    @Test func PlatformNodesForOtherPlatformsAreLeftOut() throws
    {
        let JSON = """
        { "Name": "Root", "Children": [
            { "Name": "Here", "Platform": "macOS", "Children": [ { "Name": "A", "Filter": "A" } ] },
            { "Name": "There", "Platform": "iOS", "Children": [ { "Name": "B", "Filter": "B" } ] },
            { "Name": "Everywhere", "Children": [ { "Name": "C", "Filter": "C" } ] } ] }
        """
        let Names = try FilterTreeLoader.Load(JSON: JSON).Leaves().compactMap{$0.Filter}
        #expect(Names == ["A", "C"])
    }

    @Test func CannyFindsEdgesOfTheSquare() async throws
    {
        let Result = try await FilterServer().Run(Filter: OpenCVCanny.FilterName, With: Square(), nil)
        #expect(Result.width == 64 && Result.height == 64)
        #expect(Pixel(Result, 32, 32) == [0, 0, 0, 255])
        #expect(Pixel(Result, 3, 3) == [0, 0, 0, 255])
        var Edge = 0
        for X in 0 ..< 64 where Pixel(Result, X, 32)[0] > 127
        {
            Edge += 1
        }
        // One edge on each side of the square, each a pixel or two wide.
        #expect(Edge >= 2 && Edge <= 8)
    }

    @Test func AlphaIsKept() async throws
    {
        let Source = Square(Alpha: 0.5)
        let Result = try await FilterServer().Run(Filter: OpenCVBilateral.FilterName, With: Source, nil)
        // Flat areas come back as they were, alpha included (the color is premultiplied, so it is kept to within rounding).
        for (X, Y) in [(32, 32), (5, 5)]
        {
            let Before = Pixel(Source, X, Y)
            let After = Pixel(Result, X, Y)
            #expect(After[3] == Before[3])
            #expect(abs(After[0] - Before[0]) <= 2)
        }
        let Clear = try await FilterServer().Run(Filter: OpenCVBilateral.FilterName, With: Square(Alpha: 0), nil)
        #expect(Pixel(Clear, 5, 5) == [0, 0, 0, 0])
    }

    @Test func BilateralKeepsTheEdgeSharp() async throws
    {
        let Result = try await FilterServer().Run(Filter: OpenCVBilateral.FilterName, With: Square(), nil)
        #expect(Pixel(Result, 32, 32)[0] > 250)
        #expect(Pixel(Result, 5, 5)[0] < 5)
    }

    @Test func AdaptiveThresholdInvertSwapsBlackAndWhite() async throws
    {
        let Server = FilterServer()
        let Plain = try await Server.Run(Filter: OpenCVAdaptiveThreshold.FilterName, With: Square(), nil)
        let Inverted = try await Server.Run(Filter: OpenCVAdaptiveThreshold.FilterName, With: Square(), ["INVERT": "true"])
        // Flat areas are all above the average minus C, so they are white, or black when inverted.
        #expect(Pixel(Plain, 5, 5)[0] == 255)
        #expect(Pixel(Inverted, 5, 5)[0] == 0)
    }

    @Test func DilateGrowsAndErodeShrinksTheSquare() async throws
    {
        let Server = FilterServer()
        let Dilated = try await Server.Run(Filter: OpenCVMorphology.FilterName, With: Square(), ["OPERATION": "DILATE", "SIZE": "5"])
        let Eroded = try await Server.Run(Filter: OpenCVMorphology.FilterName, With: Square(), ["OPERATION": "ERODE", "SIZE": "5"])
        // A pixel 2 outside the square's edge turns white when dilated; one 2 inside turns black when eroded.
        #expect(Pixel(Dilated, 18, 32)[0] == 255)
        #expect(Pixel(Eroded, 21, 32)[0] == 0)
        #expect(Pixel(Eroded, 32, 32)[0] == 255)
    }

    @Test func ClaheKeepsSizeAndRaisesDarkContrast() async throws
    {
        let Result = try await FilterServer().Run(Filter: OpenCVCLAHE.FilterName, With: Square(), ["CLIP": "4"])
        #expect(Result.width == 64 && Result.height == 64)
        #expect(Pixel(Result, 32, 32)[0] > Pixel(Result, 5, 5)[0])
    }

    /// A 16 x 16 raw image of a plain red scene: 255 where a mosaic has a red filter, 0 elsewhere, with red at the top left and every
    /// second pixel across and down (the layout OpenCV calls RGGB, which the filter's "BGGR" setting decodes).
    private func RedMosaic() -> CGImage
    {
        let Context = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let Bytes = Context.data!.assumingMemoryBound(to: UInt8.self)
        for Y in 0 ..< 16
        {
            for X in 0 ..< 16
            {
                let Value: UInt8 = (X % 2 == 0 && Y % 2 == 0) ? 255 : 0
                Bytes[(Y * 16 + X) * 4] = Value
                Bytes[(Y * 16 + X) * 4 + 1] = Value
                Bytes[(Y * 16 + X) * 4 + 2] = Value
                Bytes[(Y * 16 + X) * 4 + 3] = 255
            }
        }
        return Context.makeImage()!
    }

    @Test func DemosaicMakesAColorImageFromARawOne() async throws
    {
        let Server = FilterServer()
        let Result = try await Server.Run(Filter: OpenCVBayerDemosaic.FilterName, With: RedMosaic(), nil)
        #expect(Result.width == 16 && Result.height == 16)
        // The scene is red everywhere, including pixels that only had a green or blue filter.
        for (X, Y) in [(8, 8), (7, 8), (8, 7), (7, 7)]
        {
            let Color = Pixel(Result, X, Y)
            #expect(Color[0] > 200 && Color[1] < 20 && Color[2] < 20 && Color[3] == 255)
        }
        // The pattern matters: with the one for the other corner the same raw image comes out as another color.
        let Wrong = try await Server.Run(Filter: OpenCVBayerDemosaic.FilterName, With: RedMosaic(), ["PATTERN": "RGGB"])
        #expect(Pixel(Wrong, 8, 8)[2] > 200 && Pixel(Wrong, 8, 8)[0] < 20)
        // VNG does the same job.
        let Better = try await Server.Run(Filter: OpenCVBayerDemosaic.FilterName, With: RedMosaic(), ["VNG": "true"])
        #expect(Pixel(Better, 8, 8)[0] > 200 && Pixel(Better, 8, 8)[2] < 20)
    }
}
#endif
