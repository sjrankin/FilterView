//
//  ImageBackgroundView.swift
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

import SwiftUI

/// What is drawn behind an image so its transparent areas can be seen: black, white, or a checkerboard, as set in the settings dialog.
struct ImageBackgroundView: View
{
    /// Shows this background instead of the one in the settings, for the preview in the settings dialog.
    var Override: ImageBackgrounds? = nil

    var body: some View
    {
        switch Override ?? AppSettings.Shared.ImageBackground
        {
            case .Black:
                Color.black

            case .White:
                Color.white

            case .Checkerboard:
                Checkerboard()
        }
    }
}

#Preview
{
    ImageBackgroundView(Override: .Checkerboard)
}
