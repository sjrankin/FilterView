//
//  ImageBackgrounds.swift
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

/// What is shown behind an image where it is transparent: in the main window's image view, and in recorded video, which cannot hold
/// transparency.
enum ImageBackgrounds: String, CaseIterable, Identifiable, Sendable
{
    case Black = "Black"
    case White = "White"
    case Checkerboard = "Checkerboard"

    var id: String
    {
        rawValue
    }

    /// The name shown to the user.
    var Title: String
    {
        rawValue
    }
}
