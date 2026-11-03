//
//  ColorRegionTests.swift
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

@MainActor
struct ColorRegionTests
{
    /// An opaque, strongly colored image, 100 x 100.
    private func Source(Alpha: UInt8 = 255) -> CGImage
    {
        let Count = 100 * 100
        var Pixels = [UInt8]()
        Pixels.reserveCapacity(Count * 4)
        // Orange, premultiplied by the alpha.
        let Red = Int(204) * Int(Alpha) / 255
        let Green = Int(102) * Int(Alpha) / 255
        let Blue = Int(51) * Int(Alpha) / 255
        for _ in 0 ..< Count
        {
            Pixels.append(UInt8(Red))
            Pixels.append(UInt8(Green))
            Pixels.append(UInt8(Blue))
            Pixels.append(Alpha)
        }
        let Provider = CGDataProvider(data: Data(Pixels) as CFData)!
        return CGImage(width: 100, height: 100, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: Provider, decode: nil,
                       shouldInterpolate: false, intent: .defaultIntent)!
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

    private func Run(_ Options: [String: String], From Image: CGImage? = nil) async throws -> CGImage
    {
        try await FilterServer().Run(Filter: ColorRegion.FilterName, With: Image ?? Source(), Options)
    }

    /// The color of the source, and the gray (Rec. 709 brightness) it goes to.
    private let Color = [204, 102, 51]
    private var Gray: Int
    {
        let Red: Double = 0.2126 * 204.0
        let Green: Double = 0.7152 * 102.0
        let Blue: Double = 0.0722 * 51.0
        return Int((Red + Green + Blue).rounded())
    }

    private func Near(_ A: Int, _ B: Int, _ Allowed: Int = 3) -> Bool
    {
        abs(A - B) <= Allowed
    }

    @Test func LevelZeroMakesTheRegionFullyGrayAndLeavesTheRestAlone() async throws
    {
        let Result = try await Run(["SHAPE": "CIRCLE", "SIZE": "50", "MODE": "SET", "LEVEL": "0"])
        let Inside = Pixel(Result, 50, 50)
        #expect(Near(Inside[0], Gray) && Near(Inside[1], Gray) && Near(Inside[2], Gray))
        #expect(Inside[3] == 255)
        #expect(Pixel(Result, 5, 5) == [204, 102, 51, 255])
        #expect(Pixel(Result, 90, 50) == [204, 102, 51, 255])
    }

    @Test func LevelOneIsTheColorUnchanged() async throws
    {
        let Result = try await Run(["SHAPE": "CIRCLE", "SIZE": "50", "MODE": "SET", "LEVEL": "1"])
        #expect(Pixel(Result, 50, 50) == [204, 102, 51, 255])
    }

    @Test func ALevelBetweenIsProportionalBetweenGrayAndColor() async throws
    {
        for Level in [0.25, 0.5, 0.75]
        {
            let Result = try await Run(["SIZE": "50", "MODE": "SET", "LEVEL": "\(Level)"])
            let Inside = Pixel(Result, 50, 50)
            for Channel in 0 ..< 3
            {
                let Wanted = Double(Gray) + (Double(Color[Channel]) - Double(Gray)) * Level
                #expect(Near(Inside[Channel], Int(Wanted.rounded())), "level \(Level) channel \(Channel)")
            }
        }
    }

    @Test func FadingGoesFromGrayAtTheCenterToFullColorAtTheEdge() async throws
    {
        // Radius 40: gray in the middle, halfway at 20 out, and nearly the full color just inside the edge.
        let Result = try await Run(["SHAPE": "CIRCLE", "SIZE": "80", "MODE": "FADEOUT"])
        let Center = Pixel(Result, 50, 50)
        #expect(Near(Center[0], Gray, 8) && Near(Center[2], Gray, 8))
        let Half = Pixel(Result, 70, 50)
        #expect(Near(Half[0], (Gray + Color[0]) / 2, 6))
        #expect(Near(Half[2], (Gray + Color[2]) / 2, 6))
        let Near_Edge = Pixel(Result, 88, 50)
        #expect(Near(Near_Edge[0], Color[0], 12))
        #expect(Pixel(Result, 95, 50) == [204, 102, 51, 255])
    }

    @Test func InvertedSetChangesTheSurroundingsAndKeepsTheShape() async throws
    {
        let Result = try await Run(["SIZE": "50", "MODE": "SET", "LEVEL": "0", "INVERT": "true"])
        #expect(Pixel(Result, 50, 50) == [204, 102, 51, 255])
        let Outside = Pixel(Result, 5, 5)
        #expect(Near(Outside[0], Gray) && Near(Outside[1], Gray) && Near(Outside[2], Gray))
    }

    @Test func InvertedFadeIsColorAtTheCenterGrayAtTheEdgeAndGrayBeyond() async throws
    {
        let Result = try await Run(["SIZE": "80", "MODE": "FADEOUT", "INVERT": "true"])
        let Center = Pixel(Result, 50, 50)
        #expect(Near(Center[0], Color[0], 8))
        let Half = Pixel(Result, 70, 50)
        #expect(Near(Half[0], (Gray + Color[0]) / 2, 6))
        let Beyond = Pixel(Result, 98, 98)
        #expect(Near(Beyond[0], Gray) && Near(Beyond[2], Gray))
    }

    @Test func AlphaIsNeverChanged() async throws
    {
        // A half-transparent pixel: premultiplied 102, 51, 25 with alpha 128. Gray stays half-transparent.
        let Half = Source(Alpha: 128)
        let Result = try await Run(["SIZE": "50", "MODE": "SET", "LEVEL": "0"], From: Half)
        let Inside = Pixel(Result, 50, 50)
        #expect(Inside[3] == 128)
        #expect(Near(Inside[0], Inside[1], 2) && Near(Inside[1], Inside[2], 2))
        // Fully transparent pixels stay as they are.
        let Clear = Source(Alpha: 0)
        let ClearResult = try await Run(["SIZE": "50", "MODE": "SET", "LEVEL": "0"], From: Clear)
        #expect(Pixel(ClearResult, 50, 50) == [0, 0, 0, 0])
    }

    @Test func ItUsesTheSameRegionAsAlphaShape() async throws
    {
        // For the same options, the share of the way a pixel is from the center must be the same in both filters: alpha for one and color
        // level for the other. FADEOUT gives that share directly (alpha, or color level) for every shape.
        let Server = FilterServer()
        let Shapes: [[String: String]] = [
            ["SHAPE": "CIRCLE", "SIZE": "80"],
            ["SHAPE": "OVAL", "SIZE": "90", "ASPECT": "40", "ANGLE": "30"],
            ["SHAPE": "SQUARE", "SIZE": "70", "CENTERX": "40", "CENTERY": "60"],
            ["SHAPE": "RECTANGLE", "SIZE": "100", "ASPECT": "30", "ANGLE": "120", "CENTERX": "60"],
        ]
        for Shape in Shapes
        {
            var Options = Shape
            Options["MODE"] = "FADEOUT"
            let Alpha = try await Server.Run(Filter: AlphaShape.FilterName, With: Source(), Options)
            let Colored = try await Server.Run(Filter: ColorRegion.FilterName, With: Source(), Options)
            for Point in [(50, 50), (35, 60), (70, 40), (20, 20), (80, 75), (95, 10)]
            {
                let Share = Double(Pixel(Alpha, Point.0, Point.1)[3]) / 255.0
                let Red = Double(Pixel(Colored, Point.0, Point.1)[0])
                // Red goes from the gray to 204 as the share goes from 0 to 1.
                let Level = (Red - Double(Gray)) / (204.0 - Double(Gray))
                #expect(abs(Level - Share) < 0.06, "\(Shape) at \(Point): alpha share \(Share), color level \(Level)")
            }
        }
    }

    @Test func InvertedRegionsAlsoMatchAlphaShape() async throws
    {
        let Server = FilterServer()
        var Options: [String: String] = ["SHAPE": "OVAL", "SIZE": "80", "ASPECT": "50", "ANGLE": "45", "MODE": "FADEOUT", "INVERT": "true"]
        Options["CENTERX"] = "45"
        let Alpha = try await Server.Run(Filter: AlphaShape.FilterName, With: Source(), Options)
        let Colored = try await Server.Run(Filter: ColorRegion.FilterName, With: Source(), Options)
        for Point in [(45, 50), (30, 40), (70, 60), (10, 90), (90, 10)]
        {
            let Share = Double(Pixel(Alpha, Point.0, Point.1)[3]) / 255.0
            let Level = (Double(Pixel(Colored, Point.0, Point.1)[0]) - Double(Gray)) / (204.0 - Double(Gray))
            #expect(abs(Level - Share) < 0.06, "at \(Point)")
        }
    }

    @Test func ShapesAnglesAndAspectWork() async throws
    {
        // A rectangle 60 long and 30 wide along x: gray 25 out along x, still colored 25 out along y.
        let Wide = try await Run(["SHAPE": "RECTANGLE", "SIZE": "60", "ASPECT": "50", "ANGLE": "0", "MODE": "SET", "LEVEL": "0"])
        #expect(Near(Pixel(Wide, 75, 50)[0], Gray))
        #expect(Pixel(Wide, 50, 75) == [204, 102, 51, 255])
        let Tall = try await Run(["SHAPE": "RECTANGLE", "SIZE": "60", "ASPECT": "50", "ANGLE": "90", "MODE": "SET", "LEVEL": "0"])
        #expect(Near(Pixel(Tall, 50, 75)[0], Gray))
        #expect(Pixel(Tall, 75, 50) == [204, 102, 51, 255])
    }

    @Test func ARegionPastTheEdgeKeepsTheWholeGradient() async throws
    {
        // Centered on the top left corner with radius 40: halfway to the edge of the shape is 20 out, whether or not the rest is on the image.
        let Result = try await Run(["SHAPE": "CIRCLE", "SIZE": "80", "MODE": "FADEOUT", "CENTERX": "0", "CENTERY": "0"])
        #expect(Near(Pixel(Result, 20, 0)[0], (Gray + Color[0]) / 2, 8))
        #expect(Near(Pixel(Result, 0, 0)[0], Gray, 10))
    }

    @Test func TheTreeEntryIsInTheMetalGroup() throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        func Find(_ Node: FilterNode, _ Name: String) -> FilterNode?
        {
            Node.Name == Name ? Node : (Node.Children ?? []).compactMap{Find($0, Name)}.first
        }
        let Metal = try #require(Find(Root, "Metal"))
        let Entry = try #require(Metal.Children?.first{$0.Name == "Color Region"})
        #expect(Entry.Filter == ColorRegion.FilterName)
        #expect(Entry.Parameters?.map{$0.Key} == ["CENTERX", "CENTERY", "SHAPE", "SIZE", "ASPECT", "ANGLE", "MODE", "LEVEL", "INVERT"])
        #expect(Entry.Parameters?.first{$0.Key == "CENTERX"}?.Default == "50")
        #expect(Entry.Parameters?.first{$0.Key == "CENTERY"}?.Default == "50")
        #expect(Entry.Parameters?.first{$0.Key == "LEVEL"}?.Default == "0")
        #expect(FilterServer().GetFilter(ColorRegion.FilterName) != nil)
        // It sits with the other color filters.
        let Names = Metal.Children?.map{$0.Name} ?? []
        let Scale = try #require(Names.firstIndex(of: "Color Scale"))
        #expect(Names[Scale + 1] == "Color Region")
    }
}
