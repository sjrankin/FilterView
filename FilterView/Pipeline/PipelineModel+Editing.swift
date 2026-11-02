//
//  PipelineModel+Editing.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
//

import SwiftUI
import CoreGraphics

extension PipelineModel
{
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

    func SetSkipped(_ ID: Int, To Skipped: Bool)
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
    func DivergedFrom(_ ID: Int) -> Int?
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
    func MainLineConsumers(of ID: Int) -> [Stage]
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
    func Clear()
    {
        Stages.removeSubrange(1...)
        NextID = 1
        Dirty.removeAll()
    }

    /// Clears the pipeline and forgets where the main image came from, ready for the next pipeline.
    func Reset()
    {
        Clear()
        IgnoredSourceID = nil
    }

    /// Makes the final image the main image. The pipeline is left as it is, so it can be changed further.
    func SendBack()
    {
        guard let Final = FinalImage else
        {
            return
        }
        UseAsSource?(Final)
    }

    func TakeID() -> Int
    {
        defer
        {
            NextID += 1
        }
        return NextID
    }
}
