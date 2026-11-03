//
//  AppSettingsTests.swift
//  FilterViewTests
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

import Testing
import Foundation
@testable import FilterView

@MainActor
struct AppSettingsTests
{
    private func Suite() throws -> UserDefaults
    {
        try #require(UserDefaults(suiteName: "FilterViewTests-\(UUID().uuidString)"))
    }

    @Test func TheBackgroundIsTheCheckerboardUntilChosen() throws
    {
        #expect(AppSettings(Defaults: try Suite()).ImageBackground == .Checkerboard)
    }

    @Test func AChosenBackgroundIsRememberedByTheNextInstance() throws
    {
        let Defaults = try Suite()
        let First = AppSettings(Defaults: Defaults)
        First.ImageBackground = .White
        #expect(AppSettings(Defaults: Defaults).ImageBackground == .White)
        First.ImageBackground = .Black
        #expect(AppSettings(Defaults: Defaults).ImageBackground == .Black)
        First.ImageBackground = .Checkerboard
        #expect(AppSettings(Defaults: Defaults).ImageBackground == .Checkerboard)
    }

    @Test func TheValueIsSavedAsSoonAsItChanges() throws
    {
        let Defaults = try Suite()
        let Settings = AppSettings(Defaults: Defaults)
        Settings.ImageBackground = .Black
        #expect(Defaults.string(forKey: AppSettings.ImageBackgroundKey) == "Black")
    }

    @Test func AnUnknownSavedValueIsTheDefault() throws
    {
        let Defaults = try Suite()
        Defaults.set("Plaid", forKey: AppSettings.ImageBackgroundKey)
        #expect(AppSettings(Defaults: Defaults).ImageBackground == .Checkerboard)
    }

    @Test func ThePickerOffersBlackWhiteAndCheckerboard() throws
    {
        #expect(ImageBackgrounds.allCases.map{$0.Title} == ["Black", "White", "Checkerboard"])
    }

    @Test func TheFirstPageIsTheImageViewWithAGlyph() throws
    {
        #expect(SettingsPages.allCases.first == .Image)
        #expect(SettingsPages.Image.Title == "Image")
        #expect(!SettingsPages.Image.Glyph.isEmpty)
        #expect(SettingsPages.allCases.allSatisfy{!$0.Glyph.isEmpty && !$0.Title.isEmpty})
    }
}
