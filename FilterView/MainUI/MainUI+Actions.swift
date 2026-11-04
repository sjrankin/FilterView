//
//  MainUI+Actions.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/31/26.
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

extension MainUI
{
    /// Goes back to the built-in test image (Hana). Ends live video, by choosing Image as the input, and makes a pipeline that is open start
    /// again from the test image.
    func ResetToBuiltInImage()
    {
        Batch.Clear()
        SourceImage = Image("Hana")
        SourceName = "Built-in"
        SourceSize = nil
        MeasureBuiltInImage()
        SourceID = UUID()
        InputSource = .Image
    }

    /// Loads an image file chosen with the file importer and makes it the source image.
    /// - Parameter NewImage: The file. It is security scoped, so access is requested here.
    func ImportLoadedImage(_ NewImage: URL)
    {
        let Scope = NewImage.startAccessingSecurityScopedResource()
        defer
        {
            if Scope
            {
                NewImage.stopAccessingSecurityScopedResource()
            }
        }
        guard let Loaded = ImageUtility.LoadImage(from: NewImage) else
        {
            return
        }
        Batch.Clear()
        SourceImage = ImageUtility.CGImageToImage(Loaded)
        SourceName = NewImage.lastPathComponent
        SourceSize = CGSize(width: Loaded.width, height: Loaded.height)
        SourceID = UUID()
    }

    /// The original, unfiltered image, for the thumbnail in `OptionView`. While Video is selected that is the newest camera
    /// frame, otherwise it is the source image.
    var DisplayedSourceImage: Image?
    {
        InputSource == .Video ? LiveSource : SourceImage
    }

    /// The size in pixels of the image being filtered, for `OptionView`. While Video is selected that is the camera frame,
    /// otherwise it is the source image.
    var DisplayedSize: CGSize?
    {
        InputSource == .Video ? LiveSize : SourceSize
    }

    /// Records the size of the built-in image, which is the only source whose size is not known when it is set. Runs once when
    /// the view appears.
    func MeasureBuiltInImage()
    {
        if SourceSize == nil,
           let Built = ImageUtility.ImageToCGImage(SourceImage)
        {
            SourceSize = CGSize(width: Built.width, height: Built.height)
        }
    }

    /// Describes the image being filtered, for `OptionView`. While Video is selected that is the live camera, otherwise it is
    /// `SourceName`.
    var DisplayedSourceName: String
    {
        InputSource == .Video ? "Live video" : SourceName
    }

    /// Uses image files the user chose with Load or dropped on the image area (macOS). One file is the source image; several start batch
    /// mode, where they are shown in a grid, filtered together, and saved together.
    /// - Parameter Files: The files. Any that are not images are left out.
    func LoadImages(_ Files: [URL])
    {
        if Files.count == 1,
           let Only = Files.first
        {
            ImportLoadedImage(Only)
            return
        }
        Task
        {
            let Loaded = await Batch.Make(from: Files)
            switch Loaded.count
            {
                case 0:
                    return

                case 1:
                    ImportLoadedImage(Loaded[0].URL)

                default:
                    Batch.Start(Loaded)
            }
        }
    }

    /// Makes the focused image of the batch the current source image, so its name and size are shown and the pipeline starts from it.
    func UseFocusedBatchImage()
    {
        guard let Current = Batch.Focused else
        {
            return
        }
        SourceImage = ImageUtility.CGImageToImage(Current.Preview)
        SourceName = Current.Name
        SourceSize = Current.PixelSize
        SourceID = UUID()
    }

    /// Uses a photo from the camera as the source image. The unfiltered original is saved first (to Photos on iOS, to the
    /// Pictures folder on macOS).
    /// - Parameter Photo: The photo. `nil` if the user cancelled.
    func UseCapturedPhoto(_ Photo: CGImage?)
    {
        ShowCamera = false
        guard let Photo = Photo else
        {
            return
        }
        Batch.Clear()
        Task
        {
            do
            {
                try await OriginalPhotoSaver.Save(Photo)
            }
            catch
            {
                print("Could not save the original photo: \(error)")
            }
        }
        SourceImage = ImageUtility.CGImageToImage(Photo)
        SourceSize = CGSize(width: Photo.width, height: Photo.height)
        SourceName = "Camera photo"
        SourceID = UUID()
    }

    /// What filters an image right now: each region's filter if the image is divided, otherwise the selected filter. `nil` if there is none.
    var ActiveTransform: BatchModel.Transform?
    {
        BatchModel.FilterTransform(Server: Filters, Selection: Selection, Split: Split)
    }

    /// Divides the image into regions, or changes how it is divided. Choosing the layout already in use puts the image back together.
    /// - Parameter Layout: The layout whose button was tapped.
    func ChooseSplit(_ Layout: SplitLayouts)
    {
        guard var Current = Split else
        {
            // The filter chosen now goes to the first region, so the picture does not change until another region gets one.
            Split = SplitSetup(Layout: Layout, First: Selection)
            return
        }
        guard Current.Layout != Layout else
        {
            Split = nil
            return
        }
        Current.ChangeLayout(to: Layout)
        Split = Current
        Selection = Current.ActiveSelection
    }

    /// Removes every region's filter and puts the image back together. No filter is left selected, so the image shows as it is.
    func RemoveRegions()
    {
        Split = nil
        Selection = nil
    }

    /// Makes a region the one the filter tree and options edit.
    /// - Parameter Index: The region the user tapped.
    func SelectRegion(_ Index: Int)
    {
        guard var Current = Split else
        {
            return
        }
        Current.Activate(Index)
        Split = Current
        Selection = Current.ActiveSelection
    }

    /// Adds the selected filter to the pipeline (the Set button).
    func AddToPipeline()
    {
        guard let Selection = Selection else
        {
            return
        }
        // A saved pipeline can be a stage of another, but not of itself.
        if let Problem = Pipeline.NestingProblem(for: Selection)
        {
            Pipeline.Problem = Problem
            return
        }
        Task
        {
            await Pipeline.Add(Selection)
        }
    }

    /// Adds a Partial Splitter to the pipeline: one line of stages for each region, joined at the end.
    /// - Parameter Layout: How to divide the image.
    func AddSplitterToPipeline(_ Layout: SplitLayouts)
    {
        Task
        {
            await Pipeline.AddSplitter(Layout)
        }
    }

    /// The Conditional button. It will test the whole image (too dark, too light, too red, and so on) and branch on the result.
    /// It does nothing yet.
    func AddConditionalToPipeline()
    {
    }

    /// Makes the image shown by the pipeline's original stage the pipeline's first image: its filters are run on it again. Live
    /// video does this for every frame instead (see `RunLiveVideo`).
    func SyncPipeline()
    {
        guard Pipeline.IsOpen,
              InputSource != .Video,
              Pipeline.IgnoredSourceID != SourceID,
              let Original = ImageUtility.ImageToCGImage(SourceImage) else
        {
            return
        }
        Task
        {
            await Pipeline.Refresh(Original: Original)
        }
    }

    /// Makes the pipeline's final image the source image, ending any live video. The pipeline itself is left as it is.
    /// - Parameter Result: The image.
    func UsePipelineResult(_ Result: CGImage)
    {
        SourceImage = ImageUtility.CGImageToImage(Result)
        SourceName = "Pipeline result"
        SourceSize = CGSize(width: Result.width, height: Result.height)
        SourceID = UUID()
        // The pipeline keeps its own original image and filters; this new main image is not its new start.
        Pipeline.IgnoredSourceID = SourceID
        InputSource = .Image
    }

    /// Applies the selected filter (if any) to the image, encodes it as PNG, and shows the save dialog. In batch mode it saves every image of
    /// the batch instead.
    func PrepareExport() async
    {
        if Batch.IsActive
        {
            // Batch mode saves every image beside its original; there is no single file to choose.
            await Batch.SaveAll(From: .Main, Transform: ActiveTransform)
            return
        }
        guard var Result = ImageUtility.ImageToCGImage(SourceImage) else
        {
            return
        }
        if let Transform = ActiveTransform
        {
            do
            {
                Result = try await Transform(Result)
            }
            catch
            {
                // The unfiltered image is saved instead.
                #if DEBUG
                print("Filter failed while saving: \(error)")
                #endif
            }
        }
        guard let Encoded = ImageUtility.ImageEncoder.PNGData(Result) else
        {
            return
        }
        ExportDocument = ImageUtility.PNGImage(Data: Encoded)
        ShowExporter = true
    }

    /// Runs the camera while the input is Video, filtering each frame with the current selection.
    /// Called from a `task(id:)` on the input source: selecting anything but Video cancels it, which ends the stream and
    /// stops the camera.
    func RunLiveVideo() async
    {
        guard InputSource == .Video else
        {
            LiveImage = nil
            LiveSource = nil
            return
        }
        Camera.MaxFPS = MaxFPS
        RenderTime = nil
        do
        {
            for await Frame in try await Camera.Frames()
            {
                let StartTime = ContinuousClock.now
                let FrameSize = CGSize(width: Frame.width, height: Frame.height)
                if LiveSize != FrameSize
                {
                    LiveSize = FrameSize
                }
                var Result = Frame
                // The filter (or the regions' filters) is read for every frame, so changing it applies at once with no restart.
                let Transform = ActiveTransform
                if let Transform = Transform
                {
                    do
                    {
                        Result = try await Transform(Frame)
                    }
                    catch
                    {
                        // The unfiltered frame is shown instead. Printed for every frame that fails, as the filter is tried on each.
                        #if DEBUG
                        print("Filter failed on a live frame: \(error)")
                        #endif
                    }
                }
                LiveImage = ImageUtility.CGImageToImage(Result)
                LiveSource = ImageUtility.CGImageToImage(Frame)
                // Per frame: filtering plus converting the result for display.
                RenderTime = Transform == nil ? nil : ContinuousClock.now - StartTime
                if IsRecording
                {
                    await Recorder.Append(Result)
                }
                if Pipeline.IsOpen
                {
                    await Pipeline.Refresh(Original: Frame)
                }
            }
            // The stream ends when the input is changed. Finish any recording rather than lose it.
            await StopRecording()
        }
        catch
        {
            print("Camera failed: \(error)")
        }
    }
}
