//
//  AppSettings.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/3/26.
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

/// The program's general settings, the ones in the settings dialog. Every value is saved in `UserDefaults` the moment it changes, so it is
/// remembered the next time the program runs.
@Observable @MainActor
final class AppSettings
{
    static let Shared = AppSettings()

    /// The `UserDefaults` key of the image background.
    static let ImageBackgroundKey = "Settings.ImageBackground"

    /// What is behind transparent parts of the image in the main window, and in recorded video. Checkerboard until the user chooses.
    var ImageBackground: ImageBackgrounds
    {
        didSet
        {
            Defaults.set(ImageBackground.rawValue, forKey: AppSettings.ImageBackgroundKey)
        }
    }

    @ObservationIgnored private let Defaults: UserDefaults

    /// - Parameter Defaults: Where the settings are kept.
    init(Defaults: UserDefaults = .standard)
    {
        self.Defaults = Defaults
        // A value that is missing, or that a later version wrote and this one does not know, is the default.
        ImageBackground = Defaults.string(forKey: AppSettings.ImageBackgroundKey).flatMap{ImageBackgrounds(rawValue: $0)} ?? .Checkerboard
    }
}
