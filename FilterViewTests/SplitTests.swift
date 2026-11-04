//
//  SplitTests.swift
//  FilterViewTests
//
//  Created by Stuart Rankin on 11/4/26.
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

/// Dividing an image into regions that each get their own filter.
struct SplitTests
{
    /// An image whose left half is one color and right half another, and top and bottom differ too: each quadrant has its own color.
    private func MakeQuadrants(Width: Int = 8, Height: Int = 8, Colors: [[CGFloat]]) -> CGImage
    {
        let Context = CGContext(data: nil, width: Width, height: Height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let Layout = SplitLayouts.Quadrants
        for Index in 0 ..< 4
        {
            let Spot = Layout.Rect(Index, Width: Width, Height: Height)
            // In the context's own color space, so the pixel values are exactly what is written here.
            Context.setFillColor(CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                                         components: [Colors[Index][0], Colors[Index][1], Colors[Index][2], 1])!)
            Context.fill(CGRect(x: Spot.minX, y: CGFloat(Height) - Spot.maxY, width: Spot.width, height: Spot.height))
        }
        return Context.makeImage()!
    }

    private func Solid(_ Red: CGFloat, _ Green: CGFloat, _ Blue: CGFloat, Width: Int = 8, Height: Int = 8) -> CGImage
    {
        MakeQuadrants(Width: Width, Height: Height, Colors: Array(repeating: [Red, Green, Blue], count: 4))
    }

    /// The color of the pixel at x, y counted from the top left.
    private func Pixel(_ Image: CGImage, _ X: Int, _ Y: Int) -> [Int]
    {
        let Data = Image.dataProvider!.data! as Data
        let Offset = Y * Image.bytesPerRow + X * (Image.bitsPerPixel / 8)
        return [Int(Data[Offset]), Int(Data[Offset + 1]), Int(Data[Offset + 2])]
    }

    @Test func LayoutsCountTheirRegions()
    {
        #expect(SplitLayouts.Columns.Count == 2)
        #expect(SplitLayouts.Rows.Count == 2)
        #expect(SplitLayouts.Quadrants.Count == 4)
        #expect(SplitLayouts.Columns.SymbolName == "rectangle.split.2x1")
        #expect(SplitLayouts.Rows.SymbolName == "rectangle.split.1x2")
        #expect(SplitLayouts.Quadrants.SymbolName == "rectangle.split.2x2")
    }

    @Test(arguments: SplitLayouts.allCases)
    func RegionsTileTheImageExactlyEvenWhenItDoesNotDivideEvenly(Layout: SplitLayouts)
    {
        let Width = 101
        let Height = 53
        var Area = 0.0
        for Index in 0 ..< Layout.Count
        {
            let Spot = Layout.Rect(Index, Width: Width, Height: Height)
            Area += Spot.width * Spot.height
            #expect(Spot.minX == Spot.minX.rounded())
            #expect(Spot.maxY <= Double(Height))
            for Other in 0 ..< Index
            {
                #expect(Spot.intersection(Layout.Rect(Other, Width: Width, Height: Height)).isEmpty)
            }
        }
        #expect(Area == Double(Width * Height))
    }

    @Test func RegionsAreNumberedAcrossThenDown()
    {
        let Left = SplitLayouts.Columns.Rect(0, Width: 10, Height: 6)
        let Right = SplitLayouts.Columns.Rect(1, Width: 10, Height: 6)
        #expect(Left == CGRect(x: 0, y: 0, width: 5, height: 6))
        #expect(Right == CGRect(x: 5, y: 0, width: 5, height: 6))
        #expect(SplitLayouts.Rows.Rect(1, Width: 10, Height: 6) == CGRect(x: 0, y: 3, width: 10, height: 3))
        #expect(SplitLayouts.Quadrants.Rect(2, Width: 10, Height: 6) == CGRect(x: 0, y: 3, width: 5, height: 3))
        #expect(SplitLayouts.Quadrants.RegionName(1) == "Top Right")
    }

    @Test func EachRegionComesFromItsOwnImage()
    {
        let Background = Solid(0, 0, 0)
        let Red = Solid(1, 0, 0)
        let Blue = Solid(0, 0, 1)
        let Result = SplitCompositor.Compose(Background: Background, Layout: .Columns, Regions: [Red, Blue])!
        #expect(Result.width == 8)
        #expect(Pixel(Result, 1, 4) == [255, 0, 0])
        #expect(Pixel(Result, 6, 4) == [0, 0, 255])
    }

    @Test func OnlyTheRegionsPartOfEachImageIsUsed()
    {
        // The first image is red top left only, the second is green bottom right only. Each result region must show its own place.
        let TopLeftRed = MakeQuadrants(Colors: [[1, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]])
        let BottomRightGreen = MakeQuadrants(Colors: [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 1, 0]])
        let Result = SplitCompositor.Compose(Background: Solid(0, 0, 1), Layout: .Quadrants,
                                             Regions: [TopLeftRed, nil, nil, BottomRightGreen])!
        #expect(Pixel(Result, 1, 1) == [255, 0, 0])
        #expect(Pixel(Result, 6, 1) == [0, 0, 255])
        #expect(Pixel(Result, 1, 6) == [0, 0, 255])
        #expect(Pixel(Result, 6, 6) == [0, 255, 0])
    }

    @Test func AResultOfAnotherSizeIsScaledIntoItsRegion()
    {
        let Result = SplitCompositor.Compose(Background: Solid(0, 0, 0, Width: 8, Height: 8), Layout: .Rows,
                                             Regions: [nil, Solid(1, 1, 1, Width: 3, Height: 5)])!
        #expect(Result.width == 8)
        #expect(Result.height == 8)
        #expect(Pixel(Result, 4, 1) == [0, 0, 0])
        #expect(Pixel(Result, 4, 6) == [255, 255, 255])
        // Right at the dividing line there is no seam or leftover.
        #expect(Pixel(Result, 0, 3) == [0, 0, 0])
        #expect(Pixel(Result, 7, 4) == [255, 255, 255])
    }

    @Test func SetupStartsWithTheFilterInTheFirstRegion()
    {
        let Filter = TestSupport.MakeSelection()
        let Setup = SplitSetup(Layout: .Quadrants, First: Filter)
        #expect(Setup.Selections.count == 4)
        #expect(Setup.Selections[0] == Filter)
        #expect(Setup.Selections.dropFirst().allSatisfy{$0 == nil})
        #expect(Setup.HasFilters)
        #expect(!SplitSetup(Layout: .Rows, First: nil).HasFilters)
    }

    @Test func AssigningChangesOnlyTheActiveRegion()
    {
        var Setup = SplitSetup(Layout: .Columns, First: nil)
        Setup.Activate(1)
        Setup.Assign(TestSupport.MakeSelection("Tag", Amount: "5"))
        #expect(Setup.Selections[0] == nil)
        #expect(Setup.Selections[1]?.Options?["AMOUNT"] == "5")
        #expect(Setup.ActiveSelection?.Options?["AMOUNT"] == "5")
        Setup.Activate(7)
        #expect(Setup.Active == 1)
    }

    @Test func ChangingTheLayoutKeepsTheFiltersInOrder()
    {
        var Setup = SplitSetup(Layout: .Columns, First: TestSupport.MakeSelection("Tag", Amount: "1"))
        Setup.Activate(1)
        Setup.Assign(TestSupport.MakeSelection("Tag", Amount: "2"))
        Setup.ChangeLayout(to: .Quadrants)
        #expect(Setup.Selections.count == 4)
        #expect(Setup.Selections[0]?.Options?["AMOUNT"] == "1")
        #expect(Setup.Selections[1]?.Options?["AMOUNT"] == "2")
        #expect(Setup.Selections[3] == nil)
        Setup.Activate(3)
        Setup.ChangeLayout(to: .Rows)
        #expect(Setup.Selections.count == 2)
        #expect(Setup.Active == 1)
    }

    @Test func RenderingRunsEachRegionsFilterAndKeepsTheOthersAsTheyAre() async throws
    {
        let Server = FilterServer()
        let Source = Solid(0.25, 0.5, 0.75)
        // The built-in invert filter turns the left half to its opposite color; the right half is left alone.
        let Invert = FilterSelection(Filter: MetalInvert.FilterName, Options: nil, DisplayName: "Invert", Parameters: [])
        var Setup = SplitSetup(Layout: .Columns, First: Invert)
        let Result = try await SplitRenderer.Render(Source, Setup: Setup, Server: Server)
        #expect(Result.width == Source.width)
        let Before = Pixel(Source, 6, 4)
        #expect(Pixel(Result, 6, 4) == Before)
        let Changed = Pixel(Result, 1, 4)
        #expect(Changed != Pixel(Source, 1, 4))
        // No filters at all returns the image itself.
        Setup.Selections = [nil, nil]
        let Same = try await SplitRenderer.Render(Source, Setup: Setup, Server: Server)
        #expect(Pixel(Same, 1, 4) == Pixel(Source, 1, 4))
        #expect(SplitRenderer.Transform(Server: Server, Setup: Setup) == nil)
    }

    @Test func TheRegionsTakePlaceOfTheSingleFilterInBatchAndSaving() async throws
    {
        let Server = FilterServer()
        let Single = TestSupport.MakeSelection()
        // Without regions the single filter is used; with regions only their filters are.
        #expect(BatchModel.FilterTransform(Server: Server, Selection: Single) != nil)
        #expect(BatchModel.FilterTransform(Server: Server, Selection: nil) == nil)
        let Empty = SplitSetup(Layout: .Columns, First: nil)
        #expect(BatchModel.FilterTransform(Server: Server, Selection: Single, Split: Empty) == nil)
        let Filled = SplitSetup(Layout: .Columns, First: Single)
        #expect(BatchModel.FilterTransform(Server: Server, Selection: nil, Split: Filled) != nil)
    }
}
