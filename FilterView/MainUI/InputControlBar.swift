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
    /// True once a live video frame has arrived, so there is one to save.
    var HasFrame: Bool
    /// Called when the user taps Save Frame. Must prepare `ExportDocument` and set `ShowExporter`.
    var OnSaveFrame: () -> Void
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
    /// The width this bar was given. Decides whether it needs two rows.
    @State private var BarWidth: CGFloat = 1000
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var SizeClass
    #endif

    /// True on a narrow screen (iPhone in portrait).
    private var IsCompact: Bool
    {
        #if os(iOS)
        return SizeClass == .compact
        #else
        return false
        #endif
    }

    /// Two rows (the picker above, the buttons below) when everything does not fit on one: on a narrow screen, or with Video chosen
    /// (it adds the frame rate slider and Record) in anything less than a wide window. `AnyLayout` keeps the views' identity when
    /// this changes, so the file dialogs and the live video are not restarted by a rotation.
    private var BarLayout: AnyLayout
    {
        let Stacked = IsCompact || (InputSource == .Video && BarWidth < 700)
        return Stacked ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())
    }

    var body: some View
    {
        BarLayout
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
            .frame(minWidth: 220)
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
            HStack
            {
                if InputSource == .Video
                {
                    Text("FPS: \(MaxFPS, format: .number.precision(.fractionLength(0)))")
                        .fixedSize()
                    Slider(value: $MaxFPS, in: 1 ... 60, step: 1)
                        .frame(minWidth: 100, maxWidth: 200)
                    if IsRecording
                    {
                        Button("Stop", systemImage: "stop.circle")
                        {
                            Task
                            {
                                await OnStop()
                            }
                        }
                        .fixedSize()
                    }
                    else
                    {
                        Button("Record", systemImage: "record.circle")
                        {
                            OnRecord()
                        }
                        .foregroundStyle(.red)
                        .fixedSize()
                    }
                    Button("Save Frame", systemImage: "camera.viewfinder")
                    {
                        OnSaveFrame()
                    }
                    .disabled(!HasFrame)
                    .fixedSize()
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
                    .fixedSize()
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
                              defaultFilename: InputSource == .Video ? "Frame" : "Filtered")
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
        // The full width offered, whatever the contents need, so the width measured below does not depend on the layout chosen.
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self)
        {
            $0.size.width
        }
        action:
        {
            BarWidth = $0
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
                    HasFrame: false,
                    OnSaveFrame: {},
                    IsRecording: false,
                    Movie: nil,
                    ShowMovieExporter: $ExportingMovie,
                    OnRecord: {},
                    OnStop: {})
        .padding()
}
