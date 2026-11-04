//
//  PipelineModel+Splitter.swift
//  FilterView
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

import SwiftUI
import CoreGraphics

extension PipelineModel
{
    // MARK: Splitting the image into regions

    /// Divides the image into regions that each get their own filters, and puts the regions back together.
    ///
    /// Four kinds of stage are added after the end of the main line:
    /// - a `.Split` stage, which holds the image the regions start from;
    /// - one passthrough stage for each region, hanging under the split. Give each a filter with Use Selected Filter, and add more
    ///   filters after it; every filter runs on the whole image;
    /// - a `.Join` stage, which takes the last stage of each region's line and puts its part of the picture, the part inside that region,
    ///   in the region's place. The pipeline continues from the join.
    /// - Parameter Layout: How to divide the image.
    func AddSplitter(_ Layout: SplitLayouts) async
    {
        guard IsOpen else
        {
            return
        }
        let SplitID = TakeID()
        Stages.append(Stage(id: SplitID, Kind: .Split, Input: TipID, Layout: Layout))
        var Heads = [Int]()
        for _ in 0 ..< Layout.Count
        {
            let Head = TakeID()
            Stages.append(Stage(id: Head, Kind: .Filter, Input: SplitID, Under: true))
            Heads.append(Head)
        }
        let JoinID = TakeID()
        Stages.append(Stage(id: JoinID, Kind: .Join, Input: SplitID, Layout: Layout, Regions: Heads))
        Dirty.formUnion([SplitID, JoinID] + Heads)
        await Drain()
    }

    /// True for the stages that make up a splitter and cannot be deleted one by one: the split, the join, and the first stage of each
    /// region's line. (They can be skipped, and removed together with `RemoveSplitter`.)
    func IsPartOfSplitter(_ ID: Int) -> Bool
    {
        guard let Found = StageFor(ID) else
        {
            return false
        }
        switch Found.Kind
        {
            case .Split, .Join:
                return true

            default:
                return Found.Under && StageFor(Found.Input)?.Kind == .Split
        }
    }

    /// The split stage a splitter's stage belongs to.
    private func SplitterStage(of ID: Int) -> Stage?
    {
        guard let Found = StageFor(ID) else
        {
            return nil
        }
        switch Found.Kind
        {
            case .Split:
                return Found

            case .Join:
                return StageFor(Found.Input)

            default:
                return IsPartOfSplitter(ID) ? StageFor(Found.Input) : nil
        }
    }

    /// The name of the region a stage's line belongs to ("Left", "Top Right"), or `nil` for a stage that is not in a region's line.
    func RegionLabel(for ID: Int) -> String?
    {
        var Current = StageFor(ID)
        while let Found = Current,
              Found.Kind != .Original
        {
            if Found.Under,
               let Split = StageFor(Found.Input),
               Split.Kind == .Split,
               let Layout = Split.Layout
            {
                let Heads = Stages.filter{$0.Under && $0.Input == Split.id}.map{$0.id}.sorted()
                return Layout.RegionName(Heads.firstIndex(of: Found.id) ?? 0)
            }
            if Found.Kind == .Join || Found.Kind == .Split
            {
                return nil
            }
            Current = StageFor(Found.Input)
        }
        return nil
    }

    /// If a stage is the end of a region's line, the join takes this stage's place instead.
    func ReplaceRegionEnd(_ ID: Int, With NewID: Int)
    {
        for Where in Stages.indices
        {
            if let Region = Stages[Where].Regions.firstIndex(of: ID)
            {
                Stages[Where].Regions[Region] = NewID
                Dirty.insert(Stages[Where].id)
            }
        }
    }

    /// Takes a whole splitter out: the split, the join, and every stage in the regions' lines. What took the join's image takes the image the
    /// split took instead.
    /// - Parameter ID: Any stage of the splitter: the split, the join, or the first stage of a region's line.
    func RemoveSplitter(_ ID: Int)
    {
        guard let Split = SplitterStage(of: ID),
              let Source = Split.Input else
        {
            return
        }
        let Heads = Set(Stages.filter{$0.Under && $0.Input == Split.id}.map{$0.id})
        let Joins = Stages.filter{$0.Kind == .Join && $0.Input == Split.id}.map{$0.id}
        // Everything the regions lead to, except what comes after the join.
        let Lines = WithDescendants(Heads).subtracting(WithDescendants(Set(Joins)))
        let Gone = Lines.union(Joins).union([Split.id])
        Stages.removeAll{Gone.contains($0.id)}
        for Where in Stages.indices
        {
            if let Input = Stages[Where].Input, Gone.contains(Input)
            {
                Stages[Where].Input = Source
            }
            if let Second = Stages[Where].Second, Gone.contains(Second)
            {
                Stages[Where].Second = Source
            }
            Stages[Where].Regions = Stages[Where].Regions.map{Gone.contains($0) ? Source : $0}
        }
        Dirty.subtract(Gone)
        Dirty.formUnion(Stages.dropFirst().map{$0.id})
        Kick()
    }
}
