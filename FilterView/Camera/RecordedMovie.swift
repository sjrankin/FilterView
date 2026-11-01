//
//  RecordedMovie.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/31/26.
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// A finished recording, ready to be saved wherever the user chooses with `fileExporter`. The file is copied when saved, so it
/// stays in the temporary folder, and the user can save it again, until the next recording replaces it.
nonisolated struct RecordedMovie: Transferable
{
    /// The MP4 file written by `VideoRecorder`.
    let File: URL

    static var transferRepresentation: some TransferRepresentation
    {
        FileRepresentation(exportedContentType: .mpeg4Movie)
        {
            Movie in
            SentTransferredFile(Movie.File, allowAccessingOriginalFile: true)
        }
        // Without a suggested name SwiftUI builds a file wrapper with an empty name, which raises an exception when the user
        // chooses Export. The save dialog still starts from the default name given to `fileExporter`.
        .suggestedFileName("Recording.mp4")
    }
}
