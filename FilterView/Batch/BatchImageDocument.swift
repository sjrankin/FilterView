//
//  BatchImageDocument.swift
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
import UniformTypeIdentifiers

/// An encoded image handed to the save dialog, for a batch image that could not be saved beside its original.
struct BatchImageDocument: FileDocument
{
    static var readableContentTypes: [UTType] { [.png, .jpeg, .heic, .tiff, .bmp, .gif] }
    var Contents: Data

    init(Contents: Data)
    {
        self.Contents = Contents
    }

    init(configuration: ReadConfiguration) throws
    {
        Contents = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper
    {
        FileWrapper(regularFileWithContents: Contents)
    }
}
