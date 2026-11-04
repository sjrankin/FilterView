//
//  SplitRegionOverlay.swift
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

/// Drawn over the image while it is divided: the dividing lines, and a button for each region that makes it the one being edited.
struct SplitRegionOverlay: View
{
    let Setup: SplitSetup
    /// Called with the region the user tapped.
    let OnSelect: (Int) -> Void

    var body: some View
    {
        VStack(spacing: 0)
        {
            ForEach(0 ..< Setup.Layout.RowCount, id: \.self)
            {
                Row in
                HStack(spacing: 0)
                {
                    ForEach(0 ..< Setup.Layout.ColumnCount, id: \.self)
                    {
                        Column in
                        RegionCell(Name: Setup.Layout.RegionName(Row * Setup.Layout.ColumnCount + Column),
                                   IsActive: Setup.Active == Row * Setup.Layout.ColumnCount + Column,
                                   HasFilter: Setup.Selections[Row * Setup.Layout.ColumnCount + Column] != nil)
                        {
                            OnSelect(Row * Setup.Layout.ColumnCount + Column)
                        }
                    }
                }
            }
        }
    }
}

/// One region: a transparent button with an outline, and its name when it is the one being edited.
private struct RegionCell: View
{
    let Name: String
    let IsActive: Bool
    let HasFilter: Bool
    let OnTap: () -> Void

    var body: some View
    {
        Button(action: OnTap)
        {
            Color.clear
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay
        {
            // Two outlines, one dark and one light, so the lines show on any picture.
            Rectangle().strokeBorder(.black.opacity(0.6), lineWidth: IsActive ? 4 : 2)
            Rectangle().strokeBorder(IsActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.white.opacity(0.8)),
                                     lineWidth: IsActive ? 2 : 1)
        }
        .overlay(alignment: .topLeading)
        {
            if IsActive
            {
                Text(Name)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint, in: .capsule)
                    .padding(6)
            }
        }
        .accessibilityLabel(Name)
        .accessibilityValue(HasFilter ? "Has a filter" : "No filter")
        .accessibilityAddTraits(IsActive ? .isSelected : [])
        .help(Name)
    }
}
