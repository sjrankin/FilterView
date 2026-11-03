//
//  RecordedMovie.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/31/26.
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
