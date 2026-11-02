//
//  PipelineModel+Graph.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
//

import SwiftUI
import CoreGraphics

extension PipelineModel
{
    // MARK: Looking at the graph

    /// The stage with this number.
    func StageFor(_ ID: Int?) -> Stage?
    {
        guard let ID = ID else
        {
            return nil
        }
        return Stages.first{$0.id == ID}
    }

    func OutputOf(_ ID: Int?) -> CGImage?
    {
        StageFor(ID)?.Output
    }

    /// The stages that take an image from this one.
    func Consumers(of ID: Int) -> [Stage]
    {
        Stages.filter{$0.Input == ID || $0.Second == ID}
    }

    /// The stages in an order where every stage comes after the ones it takes images from.
    func Topological() -> [Int]
    {
        var Order = [Int]()
        var Seen = Set<Int>()
        func Visit(_ ID: Int)
        {
            guard !Seen.contains(ID),
                  let Found = StageFor(ID) else
            {
                return
            }
            Seen.insert(ID)
            if let Input = Found.Input
            {
                Visit(Input)
            }
            if let Second = Found.Second
            {
                Visit(Second)
            }
            Order.append(ID)
        }
        for Found in Stages.sorted(by: { $0.id < $1.id })
        {
            Visit(Found.id)
        }
        return Order
    }

    /// The stage and every stage it takes images from, directly or not.
    func AncestorsInclusive(_ ID: Int) -> Set<Int>
    {
        var Found = Set<Int>()
        var Pending = [ID]
        while let Next = Pending.popLast()
        {
            guard Found.insert(Next).inserted,
                  let Current = StageFor(Next) else
            {
                continue
            }
            Pending.append(contentsOf: [Current.Input, Current.Second].compactMap{$0})
        }
        return Found
    }

    /// The given stages and every stage that takes images from them, directly or not.
    func WithDescendants(_ IDs: Set<Int>) -> Set<Int>
    {
        var Found = IDs
        var Changed = true
        while Changed
        {
            Changed = false
            for Current in Stages where !Found.contains(Current.id)
            {
                if let Input = Current.Input, Found.contains(Input)
                {
                    Found.insert(Current.id)
                    Changed = true
                }
                else if let Second = Current.Second, Found.contains(Second)
                {
                    Found.insert(Current.id)
                    Changed = true
                }
            }
        }
        return Found
    }

    /// The stage at the end of the main line: the one a new filter is added after, and whose image is the final image. It is a stage
    /// that was not made by `Diverge` and that nothing but diverged stages take an image from. If there are several, the one
    /// furthest right.
    var TipID: Int
    {
        let Where = Positions()
        let Ends = Stages.filter
        {
            Candidate in
            !Candidate.Under && Consumers(of: Candidate.id).allSatisfy{$0.Under}
        }
        let Best = Ends.max
        {
            (Where[$0.id]?.Col ?? 0, $0.id) < (Where[$1.id]?.Col ?? 0, $1.id)
        }
        return Best?.id ?? 0
    }

    /// The last stage's image: the result of the whole pipeline.
    var FinalImage: CGImage?
    {
        OutputOf(TipID)
    }

    /// Where every stage is drawn. A stage goes to the right of the stages it takes images from, in the same row as the one it
    /// takes its first image from. A stage made by `Diverge` goes under the stage it took its image from. A place that is taken
    /// moves the stage down.
    func Positions() -> [Int: GridPoint]
    {
        var Placed = [Int: GridPoint]()
        var Used = Set<GridPoint>()
        for ID in Topological()
        {
            guard let Current = StageFor(ID) else
            {
                continue
            }
            var Point = GridPoint(Col: 0, Row: 0)
            if Current.Kind != .Original
            {
                let From = Placed[Current.Input ?? 0] ?? GridPoint(Col: 0, Row: 0)
                if Current.Under
                {
                    Point = GridPoint(Col: From.Col, Row: From.Row + 1)
                }
                else
                {
                    var Col = From.Col + 1
                    if let Second = Current.Second,
                       let Other = Placed[Second]
                    {
                        Col = max(Col, Other.Col + 1)
                    }
                    Point = GridPoint(Col: Col, Row: From.Row)
                }
            }
            while Used.contains(Point)
            {
                Point.Row += 1
            }
            Used.insert(Point)
            Placed[ID] = Point
        }
        return Placed
    }

    /// The stage whose image a stage really shows: skipped stages are looked through.
    func EffectiveSource(of ID: Int) -> Int
    {
        var Current = ID
        while let Found = StageFor(Current),
              Found.Skipped,
              let Input = Found.Input
        {
            Current = Input
        }
        return Current
    }

    /// The lines to draw. A line leaving a skipped stage starts at the stage that skipped stage really takes its image from, so
    /// it passes under the skipped one.
    func DrawnEdges() -> [Edge]
    {
        var Result = [Edge]()
        for Current in Stages
        {
            for Source in [Current.Input, Current.Second].compactMap({$0})
            {
                Result.append(Edge(From: EffectiveSource(of: Source), To: Current.id))
            }
        }
        return Result
    }
}
