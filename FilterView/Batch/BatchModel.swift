//
//  BatchModel.swift
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

/// Which window started a batch save, so the dialogs it needs (where to save a file, and the summary) appear over that window.
enum BatchOrigin
{
    case Main
    case Pipeline
}

/// A batch image that could not be written beside its original, waiting for the user to say where to put it.
struct BatchAsk: Identifiable
{
    let id = UUID()
    /// The name to suggest, without an extension.
    let Name: String
    let Document: BatchImageDocument
    let Format: BatchFiles.Format
}

/// Which question the user is being asked about a `BatchAsk`.
enum BatchAskMode
{
    /// Save this one as..., choose a folder for all, or skip.
    case Choosing
    /// The save dialog for this one image.
    case Exporter
    /// The dialog that chooses a folder.
    case Folder
}

/// What the user decided about a `BatchAsk`.
enum BatchAskOutcome
{
    /// Saved at this URL.
    case Saved(URL)
    /// The user chose a folder for this image and every later one that cannot be saved beside its original.
    case UseFolder(URL)
    /// The user cancelled, so this image is not saved.
    case Cancelled
    /// The save dialog reported an error.
    case Failed(String)
}

/// What a batch save did, for the message at the end.
struct BatchSummary
{
    var Saved = 0
    var Skipped = 0
    var Failures = [String]()

    var Title: String
    {
        Failures.isEmpty && Skipped == 0 ? "Batch Saved" : "Batch Finished"
    }

    var Message: String
    {
        var Lines = ["Saved \(Saved) \(Saved == 1 ? "image" : "images")."]
        if Skipped > 0
        {
            Lines.append("\(Skipped) skipped.")
        }
        if !Failures.isEmpty
        {
            Lines.append("\(Failures.count) could not be saved:")
            Lines.append(contentsOf: Failures.prefix(5))
            if Failures.count > 5
            {
                Lines.append("and \(Failures.count - 5) more.")
            }
        }
        return Lines.joined(separator: "\n")
    }
}

/// The images of batch mode: several images loaded at once, shown in a grid, filtered together, and saved together.
///
/// The grid works on preview-size copies (`BatchItem.Preview`) so a large batch does not use a large amount of memory. Saving loads
/// each file again at full size, filters it, and writes the result beside the original with `_fv` added to its name. If that folder
/// cannot be written to (the app can only write where the user has allowed it), `SaveAll` stops on that image and asks where to put it
/// (see `CurrentAsk`); the user can also cancel that one image.
@Observable @MainActor
final class BatchModel
{
    /// Filters or processes one image.
    typealias Transform = (CGImage) async throws -> CGImage

    /// The images. Empty when batch mode is not in use.
    private(set) var Items = [BatchItem]()
    /// The image the rest of the app treats as the current one (the pipeline starts from it).
    private(set) var FocusedID: UUID? = nil
    /// Changes whenever a new batch is loaded, which makes the grid filter it.
    private(set) var Revision = UUID()
    /// True while the input is something other than still images. The batch is kept, but is not in use.
    var Suspended = false
    /// True while `SaveAll` runs.
    private(set) var IsSaving = false
    /// The image waiting for the user to choose where to save it. `nil` when nothing is being asked.
    private(set) var CurrentAsk: BatchAsk? = nil
    /// Which question `CurrentAsk` is at.
    private(set) var AskMode = BatchAskMode.Choosing
    /// The folder the user chose for images that cannot be saved beside their originals, for the rest of this save.
    @ObservationIgnored private var ChosenFolder: URL? = nil
    /// The window that started the save in progress.
    private(set) var Origin = BatchOrigin.Main
    /// What the last save did. Cleared when the user dismisses the message.
    var Summary: BatchSummary? = nil
    @ObservationIgnored private var AskContinuation: CheckedContinuation<BatchAskOutcome, Never>? = nil

    /// True if there is a batch to work on.
    var IsActive: Bool
    {
        !Items.isEmpty && !Suspended
    }

    /// The focused image.
    var Focused: BatchItem?
    {
        Items.first{$0.id == FocusedID}
    }

    // MARK: Loading

    /// Loads the preview of each file. Files that are not images are left out.
    /// - Parameter URLs: The files, in the order they should appear.
    func Make(from URLs: [URL]) async -> [BatchItem]
    {
        var Made = [BatchItem]()
        for File in URLs
        {
            if let Loaded = await BatchFiles.LoadPreview(File)
            {
                Made.append(BatchItem(URL: File, Preview: Loaded.Image, PixelSize: Loaded.Size))
            }
        }
        return Made
    }

    /// Makes these images the batch, replacing any batch there was. The first is focused.
    func Start(_ NewItems: [BatchItem])
    {
        Items = NewItems
        FocusedID = NewItems.first?.id
        Revision = UUID()
        Summary = nil
    }

    /// Ends batch mode.
    func Clear()
    {
        guard !Items.isEmpty else
        {
            return
        }
        Items = []
        FocusedID = nil
        Revision = UUID()
    }

    /// Makes an image the focused one.
    func Focus(_ ID: UUID)
    {
        if Items.contains(where: {$0.id == ID})
        {
            FocusedID = ID
        }
    }

    private func Update(_ ID: UUID, _ Change: (inout BatchItem) -> Void)
    {
        if let Where = Items.firstIndex(where: {$0.id == ID})
        {
            Change(&Items[Where])
        }
    }

    /// The transform that runs a filter, or, when the image is divided into regions, each region's filter on its region. `nil` when
    /// there is nothing to run.
    /// - Parameter Server: Runs the filters.
    /// - Parameter Selection: The filter, used when the image is not divided.
    /// - Parameter Split: The regions and their filters. When it is not `nil` it is used instead of `Selection`.
    static func FilterTransform(Server: FilterServer?, Selection: FilterSelection?, Split: SplitSetup? = nil) -> Transform?
    {
        if Split != nil
        {
            return SplitRenderer.Transform(Server: Server, Setup: Split)
        }
        guard let Server = Server,
              let Selection = Selection else
        {
            return nil
        }
        return
        {
            Image in
            try await Server.Run(Filter: Selection.Filter, With: Image, Selection.Options)
        }
    }

    // MARK: Previewing

    /// Filters the preview of every image, showing each as it finishes. Without a transform the originals are shown. Stops early if
    /// the task is cancelled, which is what happens when the filter changes again.
    /// - Parameter Transform: The filter to run, or `nil` for none.
    func Preview(Transform: Transform?) async
    {
        for ID in Items.map(\.id)
        {
            // Saving writes results into the grid too, so wait until it is done.
            while IsSaving
            {
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled
                {
                    return
                }
            }
            guard let Item = Items.first(where: {$0.id == ID}) else
            {
                continue
            }
            guard let Transform = Transform else
            {
                Update(ID) { $0.Result = nil; $0.Status = .Idle }
                continue
            }
            Update(ID) { $0.Status = .Working }
            do
            {
                let Made = try await Transform(Item.Preview)
                if Task.isCancelled
                {
                    Update(ID) { $0.Status = .Idle }
                    return
                }
                Update(ID) { $0.Result = Made; $0.Status = .Idle }
            }
            catch
            {
                if Task.isCancelled || error is CancellationError
                {
                    Update(ID) { $0.Status = .Idle }
                    return
                }
                Update(ID) { $0.Result = nil; $0.Status = .Failed(error.localizedDescription) }
            }
        }
    }

    // MARK: Saving

    /// Processes every image at full size and saves it beside its original, one at a time. The grid shows each result as it is made.
    /// - Parameter Origin: The window that started this, so the dialogs open over it.
    /// - Parameter Transform: The filter or pipeline to run on each image, or `nil` to save the images as they are.
    func SaveAll(From Origin: BatchOrigin, Transform: Transform?) async
    {
        guard !IsSaving,
              IsActive else
        {
            return
        }
        IsSaving = true
        self.Origin = Origin
        Summary = nil
        var Result = BatchSummary()
        ChosenFolder = nil
        defer
        {
            IsSaving = false
            ChosenFolder = nil
        }
        for ID in Items.map(\.id)
        {
            guard let Item = Items.first(where: {$0.id == ID}) else
            {
                continue
            }
            Update(ID) { $0.Status = .Working }
            func Fail(_ Reason: String)
            {
                Update(ID) { $0.Status = .Failed(Reason) }
                Result.Failures.append("\(Item.Name): \(Reason)")
            }
            guard let Full = await BatchFiles.LoadFull(Item.URL) else
            {
                Fail("the image could not be read")
                continue
            }
            var Output = Full
            if let Transform = Transform
            {
                do
                {
                    Output = try await Transform(Full)
                }
                catch
                {
                    Fail(error.localizedDescription)
                    continue
                }
            }
            let Small = await BatchFiles.MakePreview(Output)
            Update(ID) { $0.Result = Small }
            let Format = BatchFiles.OutputFormat(for: Item.URL)
            guard let Encoded = await BatchFiles.EncodeAsync(Output, as: Format) else
            {
                Fail("the image could not be encoded")
                continue
            }
            let Target = BatchFiles.OutputURL(for: Item.URL)
            do
            {
                try await BatchFiles.Write(Encoded, to: Target, Original: Item.URL)
                Update(ID) { $0.Status = .Saved(Target) }
                Result.Saved += 1
            }
            catch
            {
                // Most likely the app may not write in that folder. Use the folder the user chose earlier, or ask.
                if let Folder = ChosenFolder,
                   let Where = try? await BatchFiles.Write(Encoded, named: Target.lastPathComponent, in: Folder)
                {
                    Update(ID) { $0.Status = .Saved(Where) }
                    Result.Saved += 1
                    continue
                }
                let Name = Target.deletingPathExtension().lastPathComponent
                switch await Ask(BatchAsk(Name: Name, Document: BatchImageDocument(Contents: Encoded), Format: Format))
                {
                    case .Saved(let Where):
                        Update(ID) { $0.Status = .Saved(Where) }
                        Result.Saved += 1

                    case .UseFolder(let Folder):
                        do
                        {
                            let Where = try await BatchFiles.Write(Encoded, named: Target.lastPathComponent, in: Folder)
                            ChosenFolder = Folder
                            Update(ID) { $0.Status = .Saved(Where) }
                            Result.Saved += 1
                        }
                        catch
                        {
                            Fail(error.localizedDescription)
                        }

                    case .Cancelled:
                        Update(ID) { $0.Status = .Skipped }
                        Result.Skipped += 1

                    case .Failed(let Reason):
                        Fail(Reason)
                }
            }
        }
        Summary = Result
    }

    // MARK: Asking where to save

    private func Ask(_ Question: BatchAsk) async -> BatchAskOutcome
    {
        CurrentAsk = Question
        AskMode = .Choosing
        return await withCheckedContinuation
        {
            AskContinuation = $0
        }
    }

    /// Moves the question on to a different dialog.
    func Ask(Mode: BatchAskMode)
    {
        if CurrentAsk != nil
        {
            AskMode = Mode
        }
    }

    /// Records the user's answer to `CurrentAsk`, which lets `SaveAll` go on. Does nothing if nothing is being asked.
    func Answer(_ Outcome: BatchAskOutcome)
    {
        guard let Waiting = AskContinuation else
        {
            return
        }
        AskContinuation = nil
        CurrentAsk = nil
        Waiting.resume(returning: Outcome)
    }
}
