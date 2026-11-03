//
//  ImageSettingsPage.swift
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

/// The settings of the main window's image view.
struct ImageSettingsPage: View
{
    @Bindable var Settings: AppSettings

    var body: some View
    {
        Form
        {
            Section("Image View")
            {
                Picker("Background", selection: $Settings.ImageBackground)
                {
                    ForEach(ImageBackgrounds.allCases)
                    {
                        Text($0.Title).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                // A faint disc over the background, so the choice can be judged as it will be seen behind a partly transparent image.
                ImageBackgroundView(Override: Settings.ImageBackground)
                    .frame(height: 90)
                    .overlay
                    {
                        Circle()
                            .fill(.orange.opacity(0.5))
                            .padding()
                    }
                    .clipShape(.rect(cornerRadius: 8))
                Text("Shown behind the image where it is transparent. It is also what recorded video is put on, as a video cannot be transparent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview
{
    ImageSettingsPage(Settings: AppSettings())
}
