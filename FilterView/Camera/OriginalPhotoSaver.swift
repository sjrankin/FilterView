//
//  OriginalPhotoSaver.swift
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
import CoreGraphics
#if os(iOS)
import Photos
#endif

/// Saves the unfiltered original of a photo taken with the camera. On iOS it goes into the Photos library; on macOS it is
/// written as a PNG to a `FilterView` folder inside the Pictures folder.
enum OriginalPhotoSaver
{
    /// Saves a photo.
    /// - Parameter Photo: The unfiltered photo.
    /// - Throws: `FilterException` if the photo cannot be encoded or Photos access is denied, or the file system's error
    /// if the file cannot be written.
    static func Save(_ Photo: CGImage) async throws
    {
        guard let Encoded = ImageUtility.ImageEncoder.PNGData(Photo) else
        {
            throw FilterException(Message: "Could not encode the photo")
        }
        #if os(iOS)
        // Add-only access: the app can add photos but cannot read the library.
        guard await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized else
        {
            throw FilterException(Message: "Permission to add to Photos was denied")
        }
        try await PHPhotoLibrary.shared().performChanges
        {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: Encoded, options: nil)
        }
        #else
        let Folder = RealPicturesFolder().appending(path: "FilterView", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: Folder, withIntermediateDirectories: true)
        // Local time, with dots instead of colons because colons are not valid in Finder file names.
        let Stamp = Date.now.formatted(.verbatim("\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)).\(minute: .twoDigits).\(second: .twoDigits)",
                                                 locale: .current,
                                                 timeZone: .current,
                                                 calendar: .current))
        try Encoded.write(to: Folder.appending(path: "Photo \(Stamp).png"), options: .atomic)
        #endif
    }

    #if os(macOS)
    /// The user's real Pictures folder. A sandboxed app's own `picturesDirectory` points inside its container, so the
    /// home directory is taken from the account database instead. Writing there needs the Pictures folder entitlement.
    private static func RealPicturesFolder() -> URL
    {
        if let Entry = getpwuid(getuid()),
           let Home = Entry.pointee.pw_dir
        {
            return URL(fileURLWithPath: String(cString: Home), isDirectory: true).appending(path: "Pictures", directoryHint: .isDirectory)
        }
        return URL.picturesDirectory
    }
    #endif
}
