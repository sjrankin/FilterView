//
//  SettingsView.swift
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

/// The general settings dialog. A bar down the left has a glyph and a few words for each page; tapping one opens that page on the right.
struct SettingsView: View
{
    @Environment(\.dismiss) private var Dismiss
    @State private var Page = SettingsPages.Image
    @State private var Settings = AppSettings.Shared

    var body: some View
    {
        VStack(spacing: 0)
        {
            HStack(spacing: 0)
            {
                PageBar(Page: $Page)
                Divider()
                Group
                {
                    switch Page
                    {
                        case .Image:
                            ImageSettingsPage(Settings: Settings)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            HStack
            {
                Spacer()
                Button("Done")
                {
                    Dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        #if os(macOS)
        .frame(width: 560, height: 380)
        #endif
    }
}

/// The bar of pages down the left of the dialog.
private struct PageBar: View
{
    @Binding var Page: SettingsPages

    var body: some View
    {
        VStack
        {
            ForEach(SettingsPages.allCases)
            {
                Choice in
                Button
                {
                    Page = Choice
                }
                label:
                {
                    VStack
                    {
                        Image(systemName: Choice.Glyph)
                            .font(.title2)
                        Text(Choice.Title)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Page == Choice ? AnyShapeStyle(.tint.opacity(0.2)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(Page == Choice ? .isSelected : [])
            }
            Spacer()
        }
        .padding(8)
        .frame(width: 88)
    }
}

#Preview
{
    SettingsView()
}
