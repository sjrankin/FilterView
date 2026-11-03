//
//  PipelineModel+Saving.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
//

import SwiftUI
import CoreGraphics

extension PipelineModel
{
    // MARK: Saving and loading

    /// The pipeline as it is now, ready to be saved. Every filter stage keeps the filter and all of its options.
    /// - Parameter Name: The name to save it under.
    func Snapshot(Name: String) -> SavedPipeline
    {
        let Kept = Stages.filter{$0.Kind != .Original}.sorted{$0.id < $1.id}
        return SavedPipeline(Name: Name.trimmingCharacters(in: .whitespacesAndNewlines), Stages: Kept.map(SavedStageFor),
                             FinalStage: Kept.isEmpty ? 0 : TipID)
    }

    private func SavedStageFor(_ Current: Stage) -> SavedStage
    {
        var Made = SavedStage(ID: Current.id, Kind: Current.Kind == .Merge ? .Merge : .Filter, Input: Current.Input ?? 0,
                              Second: Current.Second, Under: Current.Under, Skipped: Current.Skipped)
        switch Current.Kind
        {
            case .Filter:
                if let Selection = Current.Selection
                {
                    if Selection.IsPipeline,
                       let Nested = SavedPipeline.Decode(JSON: Selection.Options?[SavedPipelineFilter.OptionKey] ?? "")
                    {
                        // Held in full, so the stage needs nothing but the file it is in.
                        Made.Filter = Selection.Filter
                        Made.DisplayName = Nested.Name
                        Made.Nested = Nested
                    }
                    else
                    {
                        Made.Filter = Selection.Filter
                        Made.DisplayName = Selection.DisplayName
                        Made.Options = Selection.Options
                        Made.Parameters = Selection.Parameters
                    }
                }

            case .Merge:
                Made.MergeMode = Current.MergeMode.rawValue
                Made.MergeAmount = Current.MergeAmount

            case .Original:
                break
        }
        return Made
    }

    private func StageFor(Saved: SavedStage) -> Stage
    {
        var Made = Stage(id: Saved.ID, Kind: Saved.Kind == .Merge ? .Merge : .Filter, Input: Saved.Input, Second: Saved.Second,
                         Under: Saved.Under, MergeMode: MergeModes(rawValue: Saved.MergeMode ?? "") ?? .Multiply,
                         MergeAmount: Saved.MergeAmount ?? 1.0, Skipped: Saved.Skipped)
        if let Nested = Saved.Nested,
           let JSON = try? Nested.JSONString()
        {
            Made.Selection = FilterSelection(Filter: SavedPipelineFilter.FilterName, Options: [SavedPipelineFilter.OptionKey: JSON],
                                             DisplayName: Nested.Name, Parameters: [])
        }
        else if let Name = Saved.Filter
        {
            Made.Selection = FilterSelection(Filter: Name, Options: Saved.Options, DisplayName: Saved.DisplayName ?? Name,
                                             Parameters: Saved.Parameters ?? [])
        }
        return Made
    }

    /// Replaces the pipeline's stages with a saved pipeline's, keeping the original image, and makes the images.
    /// - Parameter Saved: The pipeline to edit.
    /// - Parameter URL: The file it came from, so saving can write over it.
    func Load(_ Saved: SavedPipeline, From URL: URL?) async
    {
        Stages = [Stages[0]] + Saved.Stages.sorted{$0.ID < $1.ID}.map(StageFor)
        NextID = (Stages.map{$0.id}.max() ?? 0) + 1
        CurrentName = Saved.Name
        CurrentURL = URL
        Dirty = Set(Stages.dropFirst().map{$0.id})
        await Drain()
    }

    /// Records that the pipeline was saved, so it can be saved over later.
    func MarkSaved(Name: String, At URL: URL)
    {
        CurrentName = Name.trimmingCharacters(in: .whitespacesAndNewlines)
        CurrentURL = URL
    }

    // MARK: Pipelines inside pipelines

    /// Why a selection cannot be added as a stage, or `nil` if it can. A saved pipeline can be a stage of any other, however deeply
    /// they nest, but never of itself or of a pipeline it is part of: the pipeline being edited cannot be (or hold) a stage with its own
    /// name.
    /// - Parameter Selection: The chosen filter or saved pipeline.
    func NestingProblem(for Selection: FilterSelection) -> String?
    {
        guard Selection.IsPipeline,
              let Name = CurrentName,
              let Nested = SavedPipeline.Decode(JSON: Selection.Options?[SavedPipelineFilter.OptionKey] ?? ""),
              Nested.Contains(Named: Name) else
        {
            return nil
        }
        return "“\(Name)” cannot be added to itself. A pipeline cannot have itself as a child, directly or inside another pipeline."
    }

    /// Why the pipeline cannot be saved under this name, or `nil` if it can. The name must be free (see
    /// `PipelineLibrary.Problem(forName:Directory:Replacing:)`), and no stage may be, or hold, a pipeline with that name.
    /// - Parameter Name: The name.
    /// - Parameter Directory: The folder it will be saved in. `nil` for the default folder.
    /// - Parameter Library: The pipelines the app knows about.
    func SaveProblem(Name: String, Directory: URL?, Library: PipelineLibrary) -> String?
    {
        let Replacing = CurrentName?.lowercased() == Name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ? CurrentURL : nil
        if let Taken = Library.Problem(forName: Name, Directory: Directory, Replacing: Replacing)
        {
            return Taken
        }
        if Snapshot(Name: Name).Stages.contains(where: {$0.Nested?.Contains(Named: Name) ?? false})
        {
            return "A pipeline cannot have itself as a child, and this one holds a pipeline named “\(Name)”."
        }
        return nil
    }

    /// Saves the pipeline in the library.
    /// - Parameter Name: The name to save it under.
    /// - Parameter Directory: The folder to save in. `nil` for the default folder.
    /// - Parameter Library: The pipelines the app knows about.
    /// - Throws: `FilterException` if the pipeline cannot be saved under this name.
    func Save(Name: String, Directory: URL?, Library: PipelineLibrary) throws
    {
        if let Problem = SaveProblem(Name: Name, Directory: Directory, Library: Library)
        {
            throw FilterException(Message: Problem)
        }
        let Replacing = CurrentName?.lowercased() == Name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ? CurrentURL : nil
        let File = try Library.Save(Snapshot(Name: Name), Directory: Directory, Replacing: Replacing)
        MarkSaved(Name: Name, At: File)
    }

    // MARK: Editing a stage's options

    /// Replaces the options of a filter stage and makes its image, and the images after it, again.
    /// - Parameter ID: The stage.
    /// - Parameter Selection: The same filter with the new options.
    func UpdateOptions(_ ID: Int, To Selection: FilterSelection)
    {
        guard let Where = Stages.firstIndex(where: {$0.id == ID && $0.Kind == .Filter}),
              Stages[Where].Selection?.Filter == Selection.Filter else
        {
            return
        }
        Stages[Where].Selection = Selection
        Dirty.insert(ID)
        Kick()
    }
}
