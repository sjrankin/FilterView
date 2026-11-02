//
//  PipelineModel.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
//

import SwiftUI
import CoreGraphics

/// A graph of filters run on an image (or on every frame of live video), keeping the image after each one.
///
/// Stage 0 is the original image. Every other stage takes one image (or, for a merge, two) from earlier stages. Most of the time
/// the stages are one line, each taking the one before; `Diverge` hangs a new line under a stage and `Merge` joins one line into
/// another. A stage can never depend on a stage that depends on it, so the graph has no loops.
/// The model only holds the stages; the Pipeline window (macOS) shows them.
@Observable @MainActor
final class PipelineModel
{
    enum Kinds
    {
        /// The image the pipeline starts from.
        case Original
        /// Runs one filter. With no filter chosen it passes its image through unchanged.
        case Filter
        /// Combines two images.
        case Merge
    }

    /// One step of the pipeline.
    struct Stage: Identifiable
    {
        /// The number shown on the stage. Never reused, even after the stage is deleted.
        let id: Int
        var Kind: Kinds
        /// The filter a `.Filter` stage runs. `nil` makes it a passthrough.
        var Selection: FilterSelection? = nil
        /// The stage whose image this one takes. For a merge, the background. `nil` only for the original.
        var Input: Int? = nil
        /// A merge's second image, merged onto the first.
        var Second: Int? = nil
        /// True for a stage made by `Diverge`: it is drawn under the stage it takes its image from.
        var Under = false
        var MergeMode = MergeModes.Multiply
        var MergeAmount = 1.0
        /// True if the stage does nothing: its image is the one it took.
        var Skipped = false
        /// The image after this stage. `nil` until it has been made.
        var Output: CGImage? = nil
        /// True if the filter or merge failed. The stage then passes its first image on unchanged.
        var Failed = false

        /// Shown under the stage's image.
        var Name: String
        {
            switch Kind
            {
                case .Original:
                    return "Original"

                case .Filter:
                    return Selection?.DisplayName ?? "Passthrough"

                case .Merge:
                    return "Merge \(Input ?? 0) + \(Second ?? 0): \(MergeMode.Title)"
            }
        }
    }

    /// Where a stage is drawn: its column (left to right) and row (top to bottom).
    struct GridPoint: Hashable
    {
        var Col: Int
        var Row: Int
    }

    /// A line from one stage to another.
    struct Edge
    {
        let From: Int
        let To: Int
    }

    /// True while the Pipeline window is open. Set by the window. `Add` does nothing when it is false.
    var IsOpen = false
    /// The filter chosen in the main window. "Use Selected Filter" puts it on a stage. Kept up to date by the main UI.
    var SelectedFilter: FilterSelection? = nil
    /// Runs the filters. Set by the main UI.
    @ObservationIgnored var Server: FilterServer? = nil
    /// Called with the final image when the user sends it back to be the main image. Set by the main UI.
    @ObservationIgnored var UseAsSource: ((CGImage) -> Void)? = nil
    private(set) var Stages = [Stage(id: 0, Kind: .Original)]
    private var NextID = 1
    /// Stages whose images must be made again (with everything after them).
    private var Dirty = Set<Int>()
    private var IsComputing = false

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

    private func OutputOf(_ ID: Int?) -> CGImage?
    {
        StageFor(ID)?.Output
    }

    /// The stages that take an image from this one.
    private func Consumers(of ID: Int) -> [Stage]
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
    private func AncestorsInclusive(_ ID: Int) -> Set<Int>
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
    private func WithDescendants(_ IDs: Set<Int>) -> Set<Int>
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

    // MARK: Changing the graph

    /// Sets the original image, then makes every stage again from it.
    /// - Parameter Original: The new original image. For live video, the newest frame.
    func Refresh(Original: CGImage) async
    {
        Stages[0].Output = Original
        Dirty.formUnion(Stages.dropFirst().map{$0.id})
        await Drain()
    }

    /// Adds a filter to the end of the main line and makes its image. Does nothing if the Pipeline window is not open.
    /// - Parameter Selection: The filter, as chosen in the filter tree.
    func Add(_ Selection: FilterSelection) async
    {
        guard IsOpen else
        {
            return
        }
        let NewID = TakeID()
        Stages.append(Stage(id: NewID, Kind: .Filter, Selection: Selection, Input: TipID))
        Dirty.insert(NewID)
        await Drain()
    }

    /// Makes the stage do nothing, so the image passes through it.
    func Skip(_ ID: Int)
    {
        SetSkipped(ID, To: true)
    }

    /// Puts a skipped stage back in the pipeline.
    func Resume(_ ID: Int)
    {
        SetSkipped(ID, To: false)
    }

    private func SetSkipped(_ ID: Int, To Skipped: Bool)
    {
        guard ID != 0,
              let Where = Stages.firstIndex(where: {$0.id == ID}) else
        {
            return
        }
        Stages[Where].Skipped = Skipped
        Dirty.insert(ID)
        Kick()
    }

    /// Takes the stage out of the pipeline. Whatever took its image takes the image the stage took instead. The original cannot be
    /// deleted.
    func Delete(_ ID: Int)
    {
        guard ID != 0,
              let Gone = StageFor(ID) else
        {
            return
        }
        let Replacement = Gone.Input ?? 0
        for Where in Stages.indices
        {
            if Stages[Where].Input == ID
            {
                Stages[Where].Input = Replacement
                Dirty.insert(Stages[Where].id)
            }
            if Stages[Where].Second == ID
            {
                Stages[Where].Second = Replacement
                Dirty.insert(Stages[Where].id)
            }
        }
        Stages.removeAll{$0.id == ID}
        Dirty.remove(ID)
        Kick()
    }

    /// Hangs a new passthrough stage under this one. It gets the image as it is after this stage. Choose a filter for it with
    /// `UseSelectedFilter`.
    func Diverge(_ ID: Int)
    {
        guard StageFor(ID) != nil else
        {
            return
        }
        let NewID = TakeID()
        Stages.append(Stage(id: NewID, Kind: .Filter, Input: ID, Under: true))
        Dirty.insert(NewID)
        Kick()
    }

    /// Gives a filter stage the filter chosen in the main window (and puts it back in the pipeline if it was skipped).
    func UseSelectedFilter(_ ID: Int)
    {
        guard let Selection = SelectedFilter,
              let Where = Stages.firstIndex(where: {$0.id == ID && $0.Kind == .Filter}) else
        {
            return
        }
        Stages[Where].Selection = Selection
        Stages[Where].Skipped = false
        Dirty.insert(ID)
        Kick()
    }

    /// The stages a stage can be merged with. A merge may never make a loop, and may only go to a stage numbered higher than the
    /// stage where the line this stage is on diverged (or this stage itself, if it is not on a diverged line).
    /// - Parameter ID: The stage to merge.
    func MergeTargets(for ID: Int) -> [Int]
    {
        guard StageFor(ID) != nil else
        {
            return []
        }
        let Upstream = AncestorsInclusive(ID)
        let Threshold = DivergedFrom(ID) ?? ID
        return Stages.filter
        {
            Candidate in
            Candidate.id > Threshold
                && !Upstream.contains(Candidate.id)
                // The merged image replaces this one for the stages after it, so none of them may lead back to `ID`.
                && !MainLineConsumers(of: Candidate.id).contains{Upstream.contains($0.id)}
        }.map{$0.id}
    }

    /// The stage the line a stage is on diverged from. `nil` if the stage is not on a diverged line.
    private func DivergedFrom(_ ID: Int) -> Int?
    {
        var Current = ID
        while let Found = StageFor(Current),
              Found.Kind != .Original,
              let Input = Found.Input
        {
            if Found.Under
            {
                return Input
            }
            Current = Input
        }
        return nil
    }

    /// The stages that continue the line `ID` is on, taking its image first.
    private func MainLineConsumers(of ID: Int) -> [Stage]
    {
        Stages.filter{$0.Input == ID && !$0.Under}
    }

    /// Merges a stage into another one. A new merge stage goes after `Target`, taking its image as the background with this
    /// stage's image merged onto it; whatever continued from `Target` now continues from the merge.
    /// - Parameter Source: The stage whose image is merged.
    /// - Parameter Target: The stage it is merged with. Must be one of `MergeTargets(for:)`.
    /// - Parameter Mode: How the two images are combined.
    /// - Parameter Amount: How much of the merge shows, 0.0 to 1.0.
    func Merge(From Source: Int, With Target: Int, Mode: MergeModes, Amount: Double)
    {
        guard MergeTargets(for: Source).contains(Target) else
        {
            return
        }
        let NewID = TakeID()
        for Where in Stages.indices where Stages[Where].Input == Target && !Stages[Where].Under
        {
            Stages[Where].Input = NewID
            Dirty.insert(Stages[Where].id)
        }
        Stages.append(Stage(id: NewID, Kind: .Merge, Input: Target, Second: Source, MergeMode: Mode, MergeAmount: Amount))
        Dirty.insert(NewID)
        Kick()
    }

    /// Takes every filter off the pipeline, keeping the original image.
    func Reset()
    {
        Stages.removeSubrange(1...)
        NextID = 1
        Dirty.removeAll()
    }

    /// Makes the final image the main image. The pipeline starts again from it, with no filters.
    func SendBack()
    {
        guard let Final = FinalImage else
        {
            return
        }
        Reset()
        UseAsSource?(Final)
    }

    private func TakeID() -> Int
    {
        defer
        {
            NextID += 1
        }
        return NextID
    }

    // MARK: Making the images

    /// Starts making the images of the dirty stages, unless that is already going on.
    private func Kick()
    {
        Task
        {
            await Drain()
        }
    }

    /// Makes the images of the dirty stages and everything after them, each from the image or images before it. Changes that
    /// come in meanwhile are picked up in another round; only one run is ever going.
    private func Drain() async
    {
        guard !IsComputing else
        {
            return
        }
        IsComputing = true
        defer
        {
            IsComputing = false
        }
        while !Dirty.isEmpty
        {
            let Batch = WithDescendants(Dirty)
            Dirty.removeAll()
            for ID in Topological() where Batch.contains(ID)
            {
                await Compute(ID)
            }
        }
    }

    /// Makes one stage's image.
    private func Compute(_ ID: Int) async
    {
        guard let Current = StageFor(ID),
              Current.Kind != .Original,
              let Incoming = OutputOf(Current.Input) else
        {
            return
        }
        var Made = Incoming
        var DidFail = false
        switch Current.Kind
        {
            case .Filter:
                if !Current.Skipped,
                   let Selection = Current.Selection,
                   let Server = Server
                {
                    do
                    {
                        Made = try await Server.Run(Filter: Selection.Filter, With: Incoming, Selection.Options)
                    }
                    catch
                    {
                        DidFail = true
                        #if DEBUG
                        print("Pipeline filter \(Selection.Filter) failed: \(error)")
                        #endif
                    }
                }

            case .Merge:
                if !Current.Skipped,
                   let Other = OutputOf(Current.Second)
                {
                    if let Merged = PipelineMerger.Merge(Background: Incoming, Foreground: Other, Mode: Current.MergeMode,
                                                         Amount: Current.MergeAmount)
                    {
                        Made = Merged
                    }
                    else
                    {
                        DidFail = true
                    }
                }

            case .Original:
                break
        }
        // The stage may have been deleted while the filter ran.
        if let Where = Stages.firstIndex(where: {$0.id == ID})
        {
            Stages[Where].Output = Made
            Stages[Where].Failed = DidFail
        }
    }
}
