//
//  BatchTests.swift
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
import ImageIO
import UniformTypeIdentifiers
@testable import FilterView

/// Batch mode: naming and encoding the saved copies, loading a batch, previewing a filter on it, saving it, and asking where to save
/// a file that cannot be written beside its original.
@MainActor
struct BatchTests
{
    private struct TestFailure: Error {}

    /// Writes a PNG of the given size into a folder.
    private func WriteImage(_ Name: String, In Folder: URL, Width: Int = 8, Height: Int = 4) throws -> URL
    {
        let File = Folder.appending(path: Name)
        let Data = try #require(BatchFiles.Encode(TestSupport.MakeImage(Width: Width, Height: Height), as: .png))
        try Data.write(to: File)
        return File
    }

    private func Size(of File: URL) throws -> CGSize
    {
        let Source = try #require(CGImageSourceCreateWithURL(File as CFURL, nil))
        let Image = try #require(CGImageSourceCreateImageAtIndex(Source, 0, nil))
        return CGSize(width: Image.width, height: Image.height)
    }

    /// Waits until the model asks where to save a file.
    private func WaitForAsk(_ Model: BatchModel) async
    {
        for _ in 0 ..< 500 where Model.CurrentAsk == nil
        {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: Names and formats

    @Test func SavedCopiesAreNamedBesideTheOriginal() throws
    {
        let Folder = URL(filePath: "/Pictures/Trip", directoryHint: .isDirectory)
        #expect(BatchFiles.OutputURL(for: Folder.appending(path: "photo.jpg")).path == "/Pictures/Trip/photo_fv.jpg")
        #expect(BatchFiles.OutputURL(for: Folder.appending(path: "Photo.PNG")).path == "/Pictures/Trip/Photo_fv.PNG")
        #expect(BatchFiles.OutputURL(for: Folder.appending(path: "a.b.tiff")).path == "/Pictures/Trip/a.b_fv.tiff")
    }

    @Test func FormatsThatCannotBeWrittenAreSavedAsPNG() throws
    {
        let Folder = URL(filePath: "/Pictures", directoryHint: .isDirectory)
        #expect(BatchFiles.OutputURL(for: Folder.appending(path: "scan.webp")).path == "/Pictures/scan_fv.png")
        #expect(BatchFiles.OutputURL(for: Folder.appending(path: "raw.dng")).path == "/Pictures/raw_fv.png")
        #expect(BatchFiles.OutputURL(for: Folder.appending(path: "noextension")).path == "/Pictures/noextension_fv.png")
        #expect(BatchFiles.OutputFormat(for: Folder.appending(path: "scan.webp")).Kind == .png)
    }

    @Test(arguments: [UTType.png, .jpeg, .tiff, .bmp])
    func EncodingMakesTheRequestedFormat(Kind: UTType) throws
    {
        let Data = try #require(BatchFiles.Encode(TestSupport.MakeImage(Width: 6, Height: 3), as: Kind))
        let Source = try #require(CGImageSourceCreateWithData(Data as CFData, nil))
        #expect(CGImageSourceGetType(Source) as String? == Kind.identifier)
        #expect(CGImageSourceGetCount(Source) == 1)
    }

    @Test func JPEGWithTransparencyIsPutOnWhite() throws
    {
        let Context = try #require(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        // Left fully transparent.
        let Clear = try #require(Context.makeImage())
        let Data = try #require(BatchFiles.Encode(Clear, as: .jpeg))
        let Source = try #require(CGImageSourceCreateWithData(Data as CFData, nil))
        let Decoded = try #require(CGImageSourceCreateImageAtIndex(Source, 0, nil))
        let Pixels = try #require(Decoded.dataProvider?.data as Data?)
        #expect(Pixels.prefix(3).allSatisfy{$0 > 240})
    }

    @Test func DownscalingKeepsTheAspectRatio() throws
    {
        let Big = TestSupport.MakeImage(Width: 400, Height: 200)
        let Small = BatchFiles.Downscaled(Big, MaxSize: 100)
        #expect(Small.width == 100)
        #expect(Small.height == 50)
        // An image that is small enough is not touched.
        #expect(BatchFiles.Downscaled(Big, MaxSize: 1000).width == 400)
    }

    @Test func PixelSizeAppliesTheOrientation() throws
    {
        let Folder = try TestSupport.MakeFolder()
        defer { try? FileManager.default.removeItem(at: Folder) }
        let File = Folder.appending(path: "rotated.jpg")
        let Destination = try #require(CGImageDestinationCreateWithURL(File as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        // Orientation 6 means the picture is stored on its side: 8 wide by 4 high is shown 4 wide by 8 high.
        CGImageDestinationAddImage(Destination, TestSupport.MakeImage(Width: 8, Height: 4),
                                   [kCGImagePropertyOrientation: 6] as CFDictionary)
        #expect(CGImageDestinationFinalize(Destination))
        #expect(BatchFiles.PixelSize(of: File) == CGSize(width: 4, height: 8))
    }

    // MARK: Loading

    @Test func MakeSkipsFilesThatAreNotImages() async throws
    {
        let Folder = try TestSupport.MakeFolder()
        defer { try? FileManager.default.removeItem(at: Folder) }
        let First = try WriteImage("one.png", In: Folder)
        let Text = Folder.appending(path: "notes.txt")
        try "not an image".write(to: Text, atomically: true, encoding: .utf8)
        let Second = try WriteImage("two.png", In: Folder, Width: 16, Height: 8)
        let Items = await BatchModel().Make(from: [First, Text, Second])
        #expect(Items.map(\.Name) == ["one.png", "two.png"])
        #expect(Items[1].PixelSize == CGSize(width: 16, height: 8))
    }

    @Test func PreviewsAreLimitedInSize() async throws
    {
        let Folder = try TestSupport.MakeFolder()
        defer { try? FileManager.default.removeItem(at: Folder) }
        let File = try WriteImage("large.png", In: Folder, Width: 2000, Height: 1000)
        let Item = try #require(await BatchModel().Make(from: [File]).first)
        #expect(Item.Preview.width == BatchFiles.PreviewPixelSize)
        #expect(Item.PixelSize == CGSize(width: 2000, height: 1000))
    }

    @Test func StartFocusesTheFirstImageAndClearEndsBatchMode() async throws
    {
        let Folder = try TestSupport.MakeFolder()
        defer { try? FileManager.default.removeItem(at: Folder) }
        let Model = BatchModel()
        #expect(!Model.IsActive)
        Model.Start(await Model.Make(from: [try WriteImage("a.png", In: Folder), try WriteImage("b.png", In: Folder)]))
        #expect(Model.IsActive)
        #expect(Model.Focused?.Name == "a.png")
        Model.Focus(Model.Items[1].id)
        #expect(Model.Focused?.Name == "b.png")
        Model.Suspended = true
        #expect(!Model.IsActive)
        Model.Suspended = false
        Model.Clear()
        #expect(!Model.IsActive)
        #expect(Model.Focused == nil)
    }

    // MARK: Previewing

    @Test func PreviewShowsTheFilterOnEveryImageAndNoneRestoresThem() async throws
    {
        let Folder = try TestSupport.MakeFolder()
        defer { try? FileManager.default.removeItem(at: Folder) }
        let Model = BatchModel()
        Model.Start(await Model.Make(from: [try WriteImage("a.png", In: Folder), try WriteImage("b.png", In: Folder)]))
        await Model.Preview { _ in TestSupport.MakeImage(Width: 2, Height: 2) }
        #expect(Model.Items.allSatisfy{$0.Result?.width == 2})
        #expect(Model.Items.allSatisfy{$0.Shown.width == 2})
        await Model.Preview(Transform: nil)
        #expect(Model.Items.allSatisfy{$0.Result == nil})
        #expect(Model.Items.allSatisfy{$0.Shown.width == 8})
    }

    @Test func AFilterThatFailsMarksOnlyThatImage() async throws
    {
        let Folder = try TestSupport.MakeFolder()
        defer { try? FileManager.default.removeItem(at: Folder) }
        let Model = BatchModel()
        Model.Start(await Model.Make(from: [try WriteImage("a.png", In: Folder, Width: 8), try WriteImage("b.png", In: Folder, Width: 6)]))
        await Model.Preview
        {
            Image in
            if Image.width == 6
            {
                throw TestFailure()
            }
            return Image
        }
        #expect(Model.Items[0].Status == .Idle)
        if case .Failed = Model.Items[1].Status {} else
        {
            Issue.record("The second image should be marked failed")
        }
    }

    // MARK: Saving

    @Test func SaveAllWritesFilteredCopiesBesideTheOriginals() async throws
    {
        let Folder = try TestSupport.MakeFolder()
        defer { try? FileManager.default.removeItem(at: Folder) }
        let Files = [try WriteImage("a.png", In: Folder, Width: 8, Height: 4), try WriteImage("b.png", In: Folder, Width: 10, Height: 5)]
        let Model = BatchModel()
        Model.Start(await Model.Make(from: Files))
        // The "filter" halves the size, which shows the saved files are what the filter made, from the full-size file.
        await Model.SaveAll(From: .Main)
        {
            Image in
            BatchFiles.Downscaled(Image, MaxSize: Image.width / 2)
        }
        #expect(try Size(of: Folder.appending(path: "a_fv.png")) == CGSize(width: 4, height: 2))
        #expect(try Size(of: Folder.appending(path: "b_fv.png")) == CGSize(width: 5, height: 3))
        // The originals are not touched.
        #expect(try Size(of: Files[0]) == CGSize(width: 8, height: 4))
        #expect(Model.Items.allSatisfy{if case .Saved = $0.Status { true } else { false }})
        #expect(Model.Items[0].Shown.width == 4)
        #expect(Model.Summary?.Saved == 2)
        #expect(Model.Summary?.Failures.isEmpty == true)
        #expect(!Model.IsSaving)
    }

    @Test func SaveAllWithoutAFilterSavesTheImagesAsTheyAre() async throws
    {
        let Folder = try TestSupport.MakeFolder()
        defer { try? FileManager.default.removeItem(at: Folder) }
        let Model = BatchModel()
        Model.Start(await Model.Make(from: [try WriteImage("a.png", In: Folder), try WriteImage("b.png", In: Folder)]))
        await Model.SaveAll(From: .Main, Transform: nil)
        #expect(try Size(of: Folder.appending(path: "a_fv.png")) == CGSize(width: 8, height: 4))
        #expect(FileManager.default.fileExists(atPath: Folder.appending(path: "b_fv.png").path))
    }

    @Test func AFailedImageDoesNotStopTheOthers() async throws
    {
        let Folder = try TestSupport.MakeFolder()
        defer { try? FileManager.default.removeItem(at: Folder) }
        let Model = BatchModel()
        Model.Start(await Model.Make(from: [try WriteImage("a.png", In: Folder, Width: 8), try WriteImage("b.png", In: Folder, Width: 6),
                                            try WriteImage("c.png", In: Folder, Width: 4)]))
        await Model.SaveAll(From: .Pipeline)
        {
            Image in
            if Image.width == 6
            {
                throw TestFailure()
            }
            return Image
        }
        #expect(FileManager.default.fileExists(atPath: Folder.appending(path: "a_fv.png").path))
        #expect(!FileManager.default.fileExists(atPath: Folder.appending(path: "b_fv.png").path))
        #expect(FileManager.default.fileExists(atPath: Folder.appending(path: "c_fv.png").path))
        #expect(Model.Summary?.Saved == 2)
        #expect(Model.Summary?.Failures.count == 1)
        #expect(Model.Origin == .Pipeline)
    }

    @Test func AFolderThatCannotBeWrittenAsksWhereToSave() async throws
    {
        let Folder = try TestSupport.MakeFolder()
        let Elsewhere = try TestSupport.MakeFolder()
        defer
        {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: Folder.path)
            try? FileManager.default.removeItem(at: Folder)
            try? FileManager.default.removeItem(at: Elsewhere)
        }
        let Model = BatchModel()
        Model.Start(await Model.Make(from: [try WriteImage("a.png", In: Folder), try WriteImage("b.png", In: Folder),
                                            try WriteImage("c.png", In: Folder)]))
        // Read and look, but not write.
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: Folder.path)
        let Saving = Task { await Model.SaveAll(From: .Main, Transform: nil) }

        // The first file: the user chooses another place.
        await WaitForAsk(Model)
        #expect(Model.CurrentAsk?.Name == "a_fv")
        #expect(Model.CurrentAsk?.Format.Kind == .png)
        let Chosen = Elsewhere.appending(path: "a_fv.png")
        try #require(Model.CurrentAsk?.Document.Contents).write(to: Chosen)
        Model.Answer(.Saved(Chosen))

        // The second: the user cancels.
        await WaitForAsk(Model)
        #expect(Model.CurrentAsk?.Name == "b_fv")
        Model.Answer(.Cancelled)

        // The third: the save dialog reports an error.
        await WaitForAsk(Model)
        Model.Answer(.Failed("disk full"))

        await Saving.value
        #expect(Model.Items[0].Status == .Saved(Chosen))
        #expect(Model.Items[1].Status == .Skipped)
        #expect(Model.Items[2].Status == .Failed("disk full"))
        #expect(Model.CurrentAsk == nil)
        #expect(Model.Summary?.Saved == 1)
        #expect(Model.Summary?.Skipped == 1)
        #expect(Model.Summary?.Failures.count == 1)
        #expect(try FileManager.default.contentsOfDirectory(atPath: Folder.path).filter{$0.contains("_fv")}.isEmpty)
        #expect(FileManager.default.fileExists(atPath: Chosen.path))
    }

    @Test func AChosenFolderTakesTheRestWithoutAskingAgain() async throws
    {
        let Folder = try TestSupport.MakeFolder()
        let Elsewhere = try TestSupport.MakeFolder()
        defer
        {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: Folder.path)
            try? FileManager.default.removeItem(at: Folder)
            try? FileManager.default.removeItem(at: Elsewhere)
        }
        let Model = BatchModel()
        Model.Start(await Model.Make(from: [try WriteImage("a.png", In: Folder), try WriteImage("b.png", In: Folder),
                                            try WriteImage("c.png", In: Folder)]))
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: Folder.path)
        let Saving = Task { await Model.SaveAll(From: .Main, Transform: nil) }
        await WaitForAsk(Model)
        #expect(Model.AskMode == .Choosing)
        Model.Ask(Mode: .Folder)
        #expect(Model.AskMode == .Folder)
        Model.Answer(.UseFolder(Elsewhere))
        // No further question: the other two go to the same folder.
        await Saving.value
        #expect(Model.CurrentAsk == nil)
        for Name in ["a_fv.png", "b_fv.png", "c_fv.png"]
        {
            #expect(FileManager.default.fileExists(atPath: Elsewhere.appending(path: Name).path))
        }
        #expect(Model.Summary?.Saved == 3)
        #expect(Model.Summary?.Skipped == 0)
        #expect(Model.Items[2].Status == .Saved(Elsewhere.appending(path: "c_fv.png")))
    }

    @Test func AnswerWithNothingAskedDoesNothing()
    {
        let Model = BatchModel()
        Model.Answer(.Cancelled)
        #expect(Model.CurrentAsk == nil)
    }

    @Test func SummaryDescribesWhatHappened()
    {
        var Result = BatchSummary()
        Result.Saved = 3
        #expect(Result.Title == "Batch Saved")
        Result.Skipped = 1
        Result.Failures = ["x.png: bad"]
        #expect(Result.Title == "Batch Finished")
        #expect(Result.Message.contains("Saved 3 images."))
        #expect(Result.Message.contains("1 skipped."))
        #expect(Result.Message.contains("x.png: bad"))
    }
}
