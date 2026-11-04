//
//  BatchItem.swift
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

import CoreGraphics
import Foundation

/// Where a batch image is in loading, filtering and saving.
enum BatchItemStatus: Equatable
{
    /// Nothing is happening to it.
    case Idle
    /// Being filtered or saved.
    case Working
    /// Written to this file.
    case Saved(URL)
    /// The user cancelled saving it.
    case Skipped
    /// Could not be filtered or saved, for the reason given.
    case Failed(String)
}

/// One image of a batch. The batch grid works on `Preview`, a copy small enough to keep many in memory; saving loads the file again
/// at full size.
struct BatchItem: Identifiable
{
    let id = UUID()
    /// The file the image was read from. The saved copy goes beside it.
    let URL: URL
    /// The original at preview size (see `BatchFiles.PreviewPixelSize`).
    let Preview: CGImage
    /// Size in pixels of the image as the filters see it when it is saved.
    let PixelSize: CGSize
    /// The preview after the current filter or pipeline. `nil` until there is one.
    var Result: CGImage? = nil
    var Status = BatchItemStatus.Idle

    /// The file's name.
    var Name: String
    {
        URL.lastPathComponent
    }

    /// What the grid shows: the filtered preview if there is one, otherwise the original.
    var Shown: CGImage
    {
        Result ?? Preview
    }
}
