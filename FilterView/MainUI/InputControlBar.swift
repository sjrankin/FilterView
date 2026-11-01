//
//  InputControlBar.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/31/26.
//

import SwiftUI
import UniformTypeIdentifiers

/// The bar under the image: the input source picker, the frame rate limit for live video, and the Load, Take Photo, and
/// Save buttons that go with the chosen input.
struct InputControlBar: View
{
    @Binding var InputSource: ImageInputSources
    /// Frame rate limit for live video, in frames per second.
    @Binding var MaxFPS: Double
    /// Set to true by the owner (after it prepares `ExportDocument`) to show the save dialog.
    @Binding var ShowExporter: Bool
    /// The filtered image to save.
    var ExportDocument: ImageUtility.PNGImage
    /// Called with the image file the user chose with Load.
    var OnLoad: (URL) -> Void
    /// Called when the user taps Take Photo.
    var OnTakePhoto: () -> Void
    /// Called when the user taps Save. Must prepare `ExportDocument` and set `ShowExporter`.
    var OnSave: () async -> Void
    /// True while live video is being recorded.
    var IsRecording: Bool
    /// The finished recording, if any. Save saves it (again, if it was already saved) until the next recording replaces it.
    var Movie: RecordedMovie?
    /// Set to true by the owner when a recording finishes, to ask the user where to save it. Save sets it too.
    @Binding var ShowMovieExporter: Bool
    /// Called when the user taps Record.
    var OnRecord: () -> Void
    /// Called when the user taps Stop. Must finish the recording and set `ShowMovieExporter`.
    var OnStop: () async -> Void
    @State private var ShowImporter = false

    var body: some View
    {
        HStack
        {
            Picker("", selection: $InputSource)
            {
                ForEach(ImageInputSources.allCases)
                {
                    SomeSource in
                    Text(SomeSource.rawValue).tag(SomeSource)
                }
            }
            .pickerStyle(.segmented)
            // The video save dialog is attached here, not to the Save button, because a view can only present one file exporter
            // and Save has the image one. This view is also always present, so the dialog can open when a recording ends
            // because the input was changed.
            .fileExporter(isPresented: $ShowMovieExporter,
                          item: Movie,
                          contentTypes: [.mpeg4Movie],
                          defaultFilename: "Recording")
            {
                Result in
                switch Result
                {
                    case .success(let Saved):
                        print("Saved video to \(Saved)")

                    case .failure(let Failure):
                        print("Saving the video failed: \(Failure)")
                }
            }
            if InputSource == .Video
            {
                Text("Max FPS: \(MaxFPS, format: .number.precision(.fractionLength(0)))")
                    .fixedSize()
                Slider(value: $MaxFPS, in: 1 ... 60, step: 1)
                    .frame(maxWidth: 160)
                if IsRecording
                {
                    Button("Stop", systemImage: "stop.circle")
                    {
                        Task
                        {
                            await OnStop()
                        }
                    }
                }
                else
                {
                    Button("Record", systemImage: "record.circle")
                    {
                        OnRecord()
                    }
                    .foregroundStyle(.red)
                }
            }
            Spacer()
            if InputSource == .Image
            {
                Button("Load")
                {
                    ShowImporter = true
                }
                .fileImporter(isPresented: $ShowImporter, allowedContentTypes: [.image])
                {
                    Result in
                    switch Result
                    {
                        case .success(let Selected):
                            OnLoad(Selected)

                        case .failure(let Failure):
                            print("Load failed: \(Failure)")
                    }
                }
            }
            if InputSource == .Camera
            {
                Button("Take Photo", systemImage: "camera")
                {
                    OnTakePhoto()
                }
                #if os(iOS)
                .disabled(!CameraPicker.IsAvailable)
                #endif
            }
            Button("Save")
            {
                if InputSource == .Video
                {
                    // Save the last recording. There is nothing to save until one has finished.
                    ShowMovieExporter = true
                }
                else
                {
                    Task
                    {
                        await OnSave()
                    }
                }
            }
            .disabled(InputSource == .Video && (IsRecording || Movie == nil))
            .fileExporter(isPresented: $ShowExporter,
                          document: ExportDocument,
                          contentType: .png,
                          defaultFilename: "Filtered")
            {
                Result in
                switch Result
                {
                    case .success(let Saved):
                        print("Saved to \(Saved)")

                    case .failure(let Failure):
                        print("Save failed: \(Failure)")
                }
            }
        }
    }
}

#Preview
{
    @Previewable @State var Source: ImageInputSources = .Image
    @Previewable @State var FPS = 15.0
    @Previewable @State var Exporting = false
    @Previewable @State var ExportingMovie = false
    InputControlBar(InputSource: $Source,
                    MaxFPS: $FPS,
                    ShowExporter: $Exporting,
                    ExportDocument: ImageUtility.PNGImage(Data: Data()),
                    OnLoad: { _ in },
                    OnTakePhoto: {},
                    OnSave: {},
                    IsRecording: false,
                    Movie: nil,
                    ShowMovieExporter: $ExportingMovie,
                    OnRecord: {},
                    OnStop: {})
        .padding()
}
