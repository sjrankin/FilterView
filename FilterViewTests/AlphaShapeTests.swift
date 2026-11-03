//
//  AlphaShapeTests.swift
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
struct AlphaShapeTests
{
    /// The alpha (0 to 1) of the pixel at x, y, counted from the top left.
    private func Alpha(_ Image: CGImage, _ X: Int, _ Y: Int) -> Double
    {
        let Context = CGContext(data: nil, width: Image.width, height: Image.height, bitsPerComponent: 8, bytesPerRow: Image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.draw(Image, in: CGRect(x: 0, y: 0, width: Image.width, height: Image.height))
        let Bytes = Context.data!.assumingMemoryBound(to: UInt8.self)
        return Double(Bytes[(Y * Image.width + X) * 4 + 3]) / 255.0
    }

    private func Run(_ Options: [String: String], Size: Int = 100) async throws -> CGImage
    {
        try await FilterServer().Run(Filter: AlphaShape.FilterName, With: TestSupport.MakeImage(Width: Size, Height: Size), Options)
    }

    @Test func SettingAlphaChangesOnlyInsideTheShape() async throws
    {
        // A circle of diameter 50 in the middle of 100 x 100.
        let Result = try await Run(["SHAPE": "CIRCLE", "SIZE": "50", "MODE": "SET", "ALPHA": "0.5"])
        #expect(abs(Alpha(Result, 50, 50) - 0.5) < 0.01)
        #expect(abs(Alpha(Result, 70, 50) - 0.5) < 0.01)
        #expect(Alpha(Result, 80, 50) == 1.0)
        #expect(Alpha(Result, 5, 5) == 1.0)
    }

    @Test func TheCenterIsTheMiddleByDefaultAndCanMove() async throws
    {
        let Middle = try await Run(["SIZE": "20", "ALPHA": "0"])
        #expect(Alpha(Middle, 50, 50) == 0)
        #expect(Alpha(Middle, 20, 20) == 1.0)
        let Moved = try await Run(["SIZE": "20", "ALPHA": "0", "CENTERX": "20", "CENTERY": "20"])
        #expect(Alpha(Moved, 20, 20) == 0)
        #expect(Alpha(Moved, 50, 50) == 1.0)
    }

    @Test func FadingOutGoesFromOpaqueAtTheEdgeToClearAtTheCenter() async throws
    {
        // Diameter 80, so the radius is 40.
        let Result = try await Run(["SHAPE": "CIRCLE", "SIZE": "80", "MODE": "FADEOUT"])
        #expect(Alpha(Result, 50, 50) < 0.05)
        #expect(abs(Alpha(Result, 50 + 20, 50) - 0.5) < 0.05)
        #expect(Alpha(Result, 50 + 38, 50) > 0.9)
        #expect(Alpha(Result, 50 + 45, 50) == 1.0)
    }

    @Test func HoleSizeSetsHowBigTheHoleIsAndTheFadeFollowsIt() async throws
    {
        // A hole 80 across has a radius of 40, so a pixel 20 from the center is halfway through its fade. In a hole 40 across (radius 20)
        // that pixel is on the edge, so it is not changed at all, and one 10 out is halfway.
        let Big = try await Run(["SHAPE": "CIRCLE", "SIZE": "80", "MODE": "FADEOUT"])
        let Small = try await Run(["SHAPE": "CIRCLE", "SIZE": "40", "MODE": "FADEOUT"])
        #expect(abs(Alpha(Big, 70, 50) - 0.5) < 0.05)
        #expect(Alpha(Small, 72, 50) == 1.0)
        #expect(abs(Alpha(Small, 60, 50) - 0.5) < 0.05)
        // Outside the hole nothing changes, so the area that changes moves with the size of the hole.
        #expect(Alpha(Big, 50 + 35, 50) < 1.0)
        #expect(Alpha(Small, 50 + 35, 50) == 1.0)
    }

    @Test func HoleSizeIsRelativeToTheImageAndMayBeBiggerThanIt() async throws
    {
        // A square 50 across on a 100 image: it covers 25 either side of the center.
        let Half = try await Run(["SHAPE": "SQUARE", "SIZE": "50", "MODE": "SET", "ALPHA": "0"])
        #expect(Alpha(Half, 50 + 24, 50) == 0)
        #expect(Alpha(Half, 50 + 27, 50) == 1.0)
        let Twice = try await Run(["SHAPE": "SQUARE", "SIZE": "200", "MODE": "SET", "ALPHA": "0"])
        #expect(Alpha(Twice, 2, 2) == 0 && Alpha(Twice, 97, 97) == 0)
    }

    @Test func ThereIsNoSeparateInnerHoleOrLongAxisControl() throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        let Entry = try #require(Root.Leaves().first{$0.Filter == AlphaShape.FilterName})
        #expect(Entry.Parameters?.contains{$0.Key == "HOLE"} == false)
        let Size = try #require(Entry.Parameters?.first{$0.Key == "SIZE"})
        #expect(Size.Title == "Hole Size %")
        #expect(Entry.Parameters?.contains{$0.Title == "Long Axis %"} == false)
    }

    @Test func InvertedSetChangesTheSurroundingsAndKeepsTheShape() async throws
    {
        let Result = try await Run(["SHAPE": "CIRCLE", "SIZE": "50", "MODE": "SET", "ALPHA": "0.25", "INVERT": "true"])
        #expect(Alpha(Result, 50, 50) == 1.0)
        #expect(Alpha(Result, 70, 50) == 1.0)
        #expect(abs(Alpha(Result, 80, 50) - 0.25) < 0.01)
        #expect(abs(Alpha(Result, 5, 5) - 0.25) < 0.01)
    }

    @Test func InvertedSetWithZeroMakesTheSurroundingsTransparent() async throws
    {
        let Result = try await Run(["SHAPE": "SQUARE", "SIZE": "50", "MODE": "SET", "ALPHA": "0", "INVERT": "true"])
        #expect(Alpha(Result, 50, 50) == 1.0)
        #expect(Alpha(Result, 90, 90) == 0)
    }

    @Test func InvertedFadeIsOpaqueAtTheCenterAndClearAtTheEdgeAndBeyond() async throws
    {
        let Result = try await Run(["SHAPE": "CIRCLE", "SIZE": "80", "MODE": "FADEOUT", "INVERT": "true"])
        #expect(Alpha(Result, 50, 50) > 0.95)
        #expect(abs(Alpha(Result, 50 + 20, 50) - 0.5) < 0.05)
        #expect(Alpha(Result, 50 + 38, 50) < 0.1)
        #expect(Alpha(Result, 50 + 45, 50) == 0)
        #expect(Alpha(Result, 2, 2) == 0)
    }

    @Test func InvertedFadeKeepsExistingTransparency() async throws
    {
        let Made = try await FilterServer().Run(Filter: BackgroundClear.FilterName, With: TestSupport.MakeImage(),
                                                ["TARGET": "336699FF", "SOURCE": "00000000", "TOLERANCE": "0.5"])
        let Result = try await FilterServer().Run(Filter: AlphaShape.FilterName, With: Made,
                                                  ["SIZE": "100", "MODE": "FADEOUT", "INVERT": "true"])
        #expect(Alpha(Result, 2, 2) == 0)
    }

    @Test func InvertedShapeStillWorksPastTheEdgeOfTheImage() async throws
    {
        // The center is the corner, radius 40: opaque at the corner, half at 20, clear beyond 40.
        let Result = try await Run(["SHAPE": "CIRCLE", "SIZE": "80", "MODE": "FADEOUT", "CENTERX": "0", "CENTERY": "0", "INVERT": "true"])
        #expect(Alpha(Result, 0, 0) > 0.95)
        #expect(abs(Alpha(Result, 20, 0) - 0.5) < 0.06)
        #expect(Alpha(Result, 60, 60) == 0)
    }

    @Test func NotInvertedByDefault() async throws
    {
        let Plain = try await Run(["SHAPE": "CIRCLE", "SIZE": "80", "MODE": "FADEOUT"])
        #expect(Alpha(Plain, 50, 50) < 0.05)
        #expect(Alpha(Plain, 2, 2) == 1.0)
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        let Entry = try #require(Root.Leaves().first{$0.Filter == AlphaShape.FilterName})
        let Invert = try #require(Entry.Parameters?.first{$0.Key == "INVERT"})
        #expect(Invert.Kind == .Toggle && Invert.Default == "false")
    }

    @Test func AShapePastTheEdgeKeepsTheGradientOfTheWholeShape() async throws
    {
        // The center is the top left corner and the radius is 40, so the image holds a quarter of the effect.
        let Result = try await Run(["SHAPE": "CIRCLE", "SIZE": "80", "MODE": "FADEOUT", "CENTERX": "0", "CENTERY": "0"])
        #expect(Alpha(Result, 0, 0) < 0.05)
        // Halfway to the edge of the shape, whether or not the rest of the shape is on the image.
        #expect(abs(Alpha(Result, 20, 0) - 0.5) < 0.06)
        #expect(abs(Alpha(Result, 0, 20) - 0.5) < 0.06)
        #expect(Alpha(Result, 60, 60) == 1.0)
    }

    @Test func ASquareUsesTheLargestOffsetAndACircleUsesTheDistance() async throws
    {
        // Half side 25, so the point 20 across and 20 down is inside a square (0.8 of the way out) and outside a circle of radius 25.
        let Square = try await Run(["SHAPE": "SQUARE", "SIZE": "50", "MODE": "FADEOUT"])
        #expect(abs(Alpha(Square, 70, 70) - 0.8) < 0.05)
        let Circle = try await Run(["SHAPE": "CIRCLE", "SIZE": "50", "MODE": "FADEOUT"])
        #expect(Alpha(Circle, 70, 70) == 1.0)
    }

    @Test func ARectangleHasALongAxisThatTheAngleTurns() async throws
    {
        // Long axis 60 (half 30) along x, short axis half of that (half 15).
        let Flat = try await Run(["SHAPE": "RECTANGLE", "SIZE": "60", "ASPECT": "50", "ANGLE": "0", "MODE": "SET", "ALPHA": "0"])
        #expect(Alpha(Flat, 50 + 25, 50) == 0)
        #expect(Alpha(Flat, 50, 50 + 25) == 1.0)
        let Tall = try await Run(["SHAPE": "RECTANGLE", "SIZE": "60", "ASPECT": "50", "ANGLE": "90", "MODE": "SET", "ALPHA": "0"])
        #expect(Alpha(Tall, 50, 50 + 25) == 0)
        #expect(Alpha(Tall, 50 + 25, 50) == 1.0)
    }

    @Test func AnOvalHasALongAxisThatTheAngleTurns() async throws
    {
        let Flat = try await Run(["SHAPE": "OVAL", "SIZE": "60", "ASPECT": "40", "ANGLE": "0", "MODE": "SET", "ALPHA": "0"])
        #expect(Alpha(Flat, 50 + 25, 50) == 0)
        #expect(Alpha(Flat, 50, 50 + 25) == 1.0)
        let Tall = try await Run(["SHAPE": "OVAL", "SIZE": "60", "ASPECT": "40", "ANGLE": "90", "MODE": "SET", "ALPHA": "0"])
        #expect(Alpha(Tall, 50, 50 + 25) == 0)
        #expect(Alpha(Tall, 50 + 25, 50) == 1.0)
    }

    @Test func FadingKeepsPixelsThatWereAlreadyTransparent() async throws
    {
        var Clear = SavedStage(ID: 1, Kind: .Filter, Input: 0, Under: false, Skipped: false)
        Clear.Filter = BackgroundClear.FilterName
        Clear.Options = ["TARGET": "336699FF", "SOURCE": "00000000", "TOLERANCE": "0.5"]
        let Made = try await FilterServer().Run(Filter: BackgroundClear.FilterName, With: TestSupport.MakeImage(), Clear.Options)
        let Result = try await FilterServer().Run(Filter: AlphaShape.FilterName, With: Made, ["SIZE": "100", "MODE": "FADEOUT"])
        #expect(Alpha(Result, 2, 2) == 0)
    }

    @Test func ThereIsNoFadeInChoice() throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        let Entry = try #require(Root.Leaves().first{$0.Filter == AlphaShape.FilterName})
        let Mode = try #require(Entry.Parameters?.first{$0.Key == "MODE"})
        #expect(Mode.Choices?.map{$0.Value} == ["SET", "FADEOUT"])
    }

    @Test func TheTreeEntryIsInTheBackgroundGroup() throws
    {
        let Root = try FilterTreeLoader.Load(Resource: "FilterTree")
        func Find(_ Node: FilterNode, _ Name: String) -> FilterNode?
        {
            Node.Name == Name ? Node : (Node.Children ?? []).compactMap{Find($0, Name)}.first
        }
        let Group = try #require(Find(Root, "Background"))
        #expect(Group.Children?.map{$0.Name} == ["Color Swap", "Alpha Shape"])
        let Entry = try #require(Find(Group, "Alpha Shape"))
        #expect(Entry.Filter == AlphaShape.FilterName)
        #expect(Entry.Parameters?.map{$0.Key} == ["CENTERX", "CENTERY", "SHAPE", "SIZE", "ASPECT", "ANGLE", "MODE", "ALPHA", "INVERT"])
        #expect(Entry.Parameters?.first{$0.Key == "CENTERX"}?.Default == "50")
        #expect(Entry.Parameters?.first{$0.Key == "CENTERY"}?.Default == "50")
    }
}
