//
//  PartialSplitterTests.swift
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

/// A filter that replaces the whole picture with one color, given as "red,green,blue" from 0 to 1 in the `COLOR` option.
final class FillFilter: ImageFilter
{
    static let FilterName = "Fill"
    var FilterType: ImageFilterTypes
    {
        .Infrastructure
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        let Parts = ((Options?["COLOR"] as? String) ?? "0,0,0").split(separator: ",").compactMap{Double($0)}
        let Context = CGContext(data: nil, width: Input.width, height: Input.height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        Context.setFillColor(CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [Parts[0], Parts[1], Parts[2], 1])!)
        Context.fill(CGRect(x: 0, y: 0, width: Input.width, height: Input.height))
        return Context.makeImage()!
    }
}

/// The Partial Splitter: a split, a line of stages for each region, and a join that puts each line's result in its region.
@MainActor
struct PartialSplitterTests
{
    private func Fill(_ Color: String) -> FilterSelection
    {
        FilterSelection(Filter: FillFilter.FilterName, Options: ["COLOR": Color], DisplayName: "Fill", Parameters: [])
    }

    private func Pass() -> FilterSelection
    {
        FilterSelection(Filter: PassThroughFilter.FilterName, Options: nil, DisplayName: "Pass", Parameters: [])
    }

    private func MakeServer() -> FilterServer
    {
        let Server = FilterServer()
        Server.BuiltInFilters[FillFilter.FilterName] = FillFilter()
        return Server
    }

    /// An open pipeline on an 8 x 8 image, with one splitter added.
    private func MakeModel(_ Layout: SplitLayouts = .Columns, WithPassBefore: Bool = false) async -> PipelineModel
    {
        let Model = PipelineModel()
        Model.Server = MakeServer()
        Model.IsOpen = true
        await Model.Refresh(Original: TestSupport.MakeImage(Width: 8, Height: 8))
        if WithPassBefore
        {
            await Model.Add(Pass())
        }
        await Model.AddSplitter(Layout)
        return Model
    }

    private func Pixel(_ Image: CGImage, _ X: Int, _ Y: Int) -> [Int]
    {
        let Data = Image.dataProvider!.data! as Data
        let Offset = Y * Image.bytesPerRow + X * (Image.bitsPerPixel / 8)
        return [Int(Data[Offset]), Int(Data[Offset + 1]), Int(Data[Offset + 2])]
    }

    private func Heads(_ Model: PipelineModel) -> [PipelineModel.Stage]
    {
        Model.Stages.filter{$0.Under}.sorted{$0.id < $1.id}
    }

    private func GiveFilters(_ Model: PipelineModel, _ Colors: [String]) async
    {
        for (Head, Color) in zip(Heads(Model), Colors)
        {
            Model.SelectedFilter = Fill(Color)
            Model.UseSelectedFilter(Head.id)
        }
        await Model.Drain()
    }

    @Test func AddingASplitterMakesTheSplitTheLinesAndTheJoin() async throws
    {
        let Model = await MakeModel(.Quadrants)
        let Split = try #require(Model.Stages.first{$0.Kind == .Split})
        let Join = try #require(Model.Stages.first{$0.Kind == .Join})
        let Lines = Heads(Model)
        #expect(Split.Input == 0)
        #expect(Split.Layout == .Quadrants)
        #expect(Lines.count == 4)
        #expect(Lines.allSatisfy{$0.Input == Split.id && $0.Under && $0.Kind == .Filter && $0.Selection == nil})
        #expect(Join.Input == Split.id)
        #expect(Join.Regions == Lines.map(\.id))
        // The pipeline continues from the join.
        #expect(Model.TipID == Join.id)
        #expect(Model.Stages.allSatisfy{$0.Kind == .Original || $0.Output != nil})
        #expect(Model.FinalImage?.width == 8)
    }

    @Test func ASplitterOnlyAddsWhileThePipelineIsOpen() async
    {
        let Model = PipelineModel()
        await Model.AddSplitter(.Columns)
        #expect(Model.Stages.count == 1)
    }

    @Test func EachRegionShowsItsOwnLinesResult() async throws
    {
        let Model = await MakeModel(.Columns)
        await GiveFilters(Model, ["1,0,0", "0,0,1"])
        let Final = try #require(Model.FinalImage)
        #expect(Pixel(Final, 1, 4) == [255, 0, 0])
        #expect(Pixel(Final, 6, 4) == [0, 0, 255])
    }

    @Test func AFilterAddedAfterARegionsFilterBecomesThatRegionsEnd() async throws
    {
        let Model = await MakeModel(.Rows)
        await GiveFilters(Model, ["1,0,0", "0,0,1"])
        let Top = try #require(Heads(Model).first)
        Model.InsertFilter(After: Top.id, With: Fill("0,1,0"))
        await Model.Drain()
        let Join = try #require(Model.Stages.first{$0.Kind == .Join})
        let NewEnd = try #require(Model.Stages.first{$0.Selection?.Options?["COLOR"] == "0,1,0"})
        #expect(Join.Regions.first == NewEnd.id)
        #expect(Model.RegionLabel(for: NewEnd.id) == "Top")
        let Final = try #require(Model.FinalImage)
        #expect(Pixel(Final, 4, 1) == [0, 255, 0])
        #expect(Pixel(Final, 4, 6) == [0, 0, 255])
        // The line is not the end of the main line: the join is.
        #expect(Model.TipID == Join.id)
    }

    @Test func DeletingTheEndOfARegionsLineFallsBackToThePreviousStage() async throws
    {
        let Model = await MakeModel(.Columns)
        await GiveFilters(Model, ["1,0,0", "0,0,1"])
        let Left = try #require(Heads(Model).first)
        Model.InsertFilter(After: Left.id, With: Fill("0,1,0"))
        await Model.Drain()
        let Extra = try #require(Model.Stages.first{$0.Selection?.Options?["COLOR"] == "0,1,0"})
        Model.Delete(Extra.id)
        await Model.Drain()
        let Join = try #require(Model.Stages.first{$0.Kind == .Join})
        #expect(Join.Regions.first == Left.id)
        #expect(Pixel(try #require(Model.FinalImage), 1, 4) == [255, 0, 0])
    }

    @Test func ThePartsOfASplitterCannotBeDeletedOneByOne() async throws
    {
        let Model = await MakeModel(.Columns)
        let Before = Model.Stages.count
        for Part in Model.Stages.filter({$0.Kind != .Original})
        {
            #expect(Model.IsPartOfSplitter(Part.id))
            Model.Delete(Part.id)
        }
        #expect(Model.Stages.count == Before)
    }

    @Test func NothingGoesBetweenTheSplitAndItsRegions() async throws
    {
        let Model = await MakeModel(.Columns)
        let Split = try #require(Model.Stages.first{$0.Kind == .Split})
        let Count = Model.Stages.count
        Model.Diverge(Split.id)
        Model.InsertFilter(After: Split.id, With: Pass())
        #expect(Model.Stages.count == Count)
        // And it cannot be merged into.
        let Other = try #require(Heads(Model).first)
        #expect(!Model.MergeTargets(for: Other.id).contains(Split.id))
        // A filter inserted before the join would only change the picture the empty parts fall back on.
        let Join = try #require(Model.Stages.first{$0.Kind == .Join})
        Model.InsertFilter(Before: Join.id, With: Pass())
        #expect(Model.Stages.count == Count)
    }

    @Test func RegionLabelsNameTheSideOfEachLine() async throws
    {
        let Model = await MakeModel(.Quadrants)
        let Names = Heads(Model).map{Model.RegionLabel(for: $0.id)}
        #expect(Names == ["Top Left", "Top Right", "Bottom Left", "Bottom Right"])
        let Split = try #require(Model.Stages.first{$0.Kind == .Split})
        let Join = try #require(Model.Stages.first{$0.Kind == .Join})
        #expect(Model.RegionLabel(for: Split.id) == nil)
        #expect(Model.RegionLabel(for: Join.id) == nil)
        #expect(Model.RegionLabel(for: 0) == nil)
    }

    @Test func TheJoinGoesRightOfEveryRegionsLine() async throws
    {
        let Model = await MakeModel(.Columns)
        await GiveFilters(Model, ["1,0,0", "0,0,1"])
        let Left = try #require(Heads(Model).first)
        // Two more stages on the left line, so it is longer than the split's own column.
        Model.InsertFilter(After: Left.id, With: Pass())
        await Model.Drain()
        let LeftEnd = try #require(Model.Stages.first{$0.Kind == .Join}?.Regions.first)
        Model.InsertFilter(After: LeftEnd, With: Pass())
        await Model.Drain()
        let Where = Model.Positions()
        let Join = try #require(Model.Stages.first{$0.Kind == .Join})
        let JoinColumn = try #require(Where[Join.id]).Col
        for Region in Join.Regions
        {
            let RegionColumn = try #require(Where[Region]).Col
            #expect(JoinColumn > RegionColumn)
        }
    }

    @Test func RemovingASplitterTakesOutEveryPartAndReconnectsTheRest() async throws
    {
        let Model = await MakeModel(.Columns, WithPassBefore: true)
        await GiveFilters(Model, ["1,0,0", "0,0,1"])
        let Left = try #require(Heads(Model).first)
        Model.InsertFilter(After: Left.id, With: Pass())
        // A stage after the join.
        await Model.Add(Pass())
        let After = try #require(Model.Stages.last)
        let Join = try #require(Model.Stages.first{$0.Kind == .Join})
        #expect(After.Input == Join.id)

        // Removing from any part of it works; here, from a region's first stage.
        Model.RemoveSplitter(Left.id)
        await Model.Drain()
        #expect(Model.Stages.allSatisfy{$0.Kind != .Split && $0.Kind != .Join && !$0.Under})
        #expect(Model.Stages.count == 3)
        // The original, the pass before the splitter, and the pass after it, reconnected.
        let Kept = try #require(Model.StageFor(After.id))
        #expect(Kept.Input == 1)
        #expect(Model.TipID == After.id)
        #expect(Model.FinalImage != nil)
    }

    @Test func ASplitterSurvivesSavingAndRunsInAPipelineAsAFilter() async throws
    {
        let Model = await MakeModel(.Quadrants)
        await GiveFilters(Model, ["1,0,0", "0,1,0", "0,0,1", "1,1,1"])
        let Saved = Model.Snapshot(Name: "Quads")
        // The saved file keeps the layout and which stages the join takes.
        let Data = try Saved.FileData()
        let Decoded = try #require(SavedPipeline.Decode(Data: Data))
        #expect(Decoded == Saved)
        let SavedJoin = try #require(Decoded.Stages.first{$0.Kind == .Join})
        #expect(SavedJoin.Layout == "2x2")
        #expect(SavedJoin.Regions?.count == 4)

        // Run without the window.
        let Result = try await PipelineExecutor.Run(Decoded, Input: TestSupport.MakeImage(Width: 8, Height: 8),
                                                    Filters: ["Fill": FillFilter(), PassThroughFilter.FilterName: PassThroughFilter()])
        #expect(Pixel(Result, 1, 1) == [255, 0, 0])
        #expect(Pixel(Result, 6, 1) == [0, 255, 0])
        #expect(Pixel(Result, 1, 6) == [0, 0, 255])
        #expect(Pixel(Result, 6, 6) == [255, 255, 255])

        // And load it back into a window.
        let Again = PipelineModel()
        Again.Server = MakeServer()
        Again.IsOpen = true
        await Again.Refresh(Original: TestSupport.MakeImage(Width: 8, Height: 8))
        await Again.Load(Decoded, From: nil)
        let Join = try #require(Again.Stages.first{$0.Kind == .Join})
        #expect(Join.Layout == .Quadrants)
        #expect(Join.Regions == Model.Stages.first{$0.Kind == .Join}?.Regions)
        #expect(Pixel(try #require(Again.FinalImage), 6, 6) == [255, 255, 255])
    }

    @Test func SkippingARegionsFirstStageLeavesThatRegionUnfiltered() async throws
    {
        let Model = await MakeModel(.Columns)
        await GiveFilters(Model, ["1,0,0", "0,0,1"])
        let Right = try #require(Heads(Model).last)
        Model.Skip(Right.id)
        await Model.Drain()
        let Final = try #require(Model.FinalImage)
        let Original = try #require(Model.Stages.first?.Output)
        #expect(Pixel(Final, 1, 4) == [255, 0, 0])
        #expect(Pixel(Final, 6, 4) == Pixel(Original, 6, 4))
    }
}
