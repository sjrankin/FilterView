//
//  MainUI+Actions.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/31/26.
//

import SwiftUI

extension MainUI
{
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
        InputSource == .Video ? "Live camera video" : SourceName
    }

    /// Makes an image file dropped on the image area (macOS) the source image.
    /// - Parameter File: The dropped file.
    /// - Parameter Loaded: The image loaded from the file.
    func UseDroppedImage(_ File: URL, _ Loaded: CGImage)
    {
        SourceImage = ImageUtility.CGImageToImage(Loaded)
        SourceName = File.lastPathComponent
        SourceSize = CGSize(width: Loaded.width, height: Loaded.height)
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
        SourceName = "Camera photo, \(Date.now.formatted(date: .abbreviated, time: .shortened))"
        SourceID = UUID()
    }

    /// Applies the selected filter (if any) to the image, encodes it as PNG, and shows the save dialog.
    func PrepareExport() async
    {
        guard var Result = ImageUtility.ImageToCGImage(SourceImage) else
        {
            return
        }
        if let Selection = Selection,
           let Server = Filters,
           let Filtered = try? await Server.Run(Filter: Selection.Filter, With: Result, Selection.Options)
        {
            Result = Filtered
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
                // The selection is read for every frame, so changing the filter applies at once with no restart.
                if let Selection = Selection,
                   let Server = Filters,
                   let Filtered = try? await Server.Run(Filter: Selection.Filter, With: Frame, Selection.Options)
                {
                    Result = Filtered
                }
                LiveImage = ImageUtility.CGImageToImage(Result)
                LiveSource = ImageUtility.CGImageToImage(Frame)
                // Per frame: filtering plus converting the result for display.
                RenderTime = Selection == nil ? nil : ContinuousClock.now - StartTime
                if IsRecording
                {
                    await Recorder.Append(Result)
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
