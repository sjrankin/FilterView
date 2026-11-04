//
//  SplitLayouts.swift
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

/// The ways an image can be divided so each part gets its own filter.
nonisolated enum SplitLayouts: String, CaseIterable, Codable, Hashable, Sendable, Identifiable
{
    /// Two halves side by side: left and right.
    case Columns = "2x1"
    /// Two halves, one above the other: top and bottom.
    case Rows = "1x2"
    /// Four quadrants.
    case Quadrants = "2x2"

    var id: String
    {
        rawValue
    }

    var ColumnCount: Int
    {
        self == .Rows ? 1 : 2
    }

    var RowCount: Int
    {
        self == .Columns ? 1 : 2
    }

    /// How many regions there are.
    var Count: Int
    {
        ColumnCount * RowCount
    }

    /// The SF Symbol that shows this layout.
    var SymbolName: String
    {
        "rectangle.split.\(rawValue)"
    }

    /// The name of the layout, for buttons and menus.
    var Title: String
    {
        switch self
        {
            case .Columns:
                return "Left and Right"

            case .Rows:
                return "Top and Bottom"

            case .Quadrants:
                return "Four Quadrants"
        }
    }

    /// The name of a region. Regions are numbered across, then down.
    /// - Parameter Index: The region, 0 up to `Count`.
    func RegionName(_ Index: Int) -> String
    {
        let Names: [String]
        switch self
        {
            case .Columns:
                Names = ["Left", "Right"]

            case .Rows:
                Names = ["Top", "Bottom"]

            case .Quadrants:
                Names = ["Top Left", "Top Right", "Bottom Left", "Bottom Right"]
        }
        return Names.indices.contains(Index) ? Names[Index] : "Region \(Index + 1)"
    }

    /// Where a region is in an image, with the origin at the top left. The edges are whole pixels and the regions tile the image exactly,
    /// even when its size does not divide evenly.
    /// - Parameter Index: The region, 0 up to `Count`.
    /// - Parameter Width: Width of the image in pixels.
    /// - Parameter Height: Height of the image in pixels.
    func Rect(_ Index: Int, Width: Int, Height: Int) -> CGRect
    {
        let Column = Index % ColumnCount
        let Row = Index / ColumnCount
        let Left = Column * Width / ColumnCount
        let Right = (Column + 1) * Width / ColumnCount
        let Top = Row * Height / RowCount
        let Bottom = (Row + 1) * Height / RowCount
        return CGRect(x: Left, y: Top, width: Right - Left, height: Bottom - Top)
    }
}
