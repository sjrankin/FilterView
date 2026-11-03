//
//  MPSMorphologyOptions.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/30/26.
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

/// Option parsing shared by `MPSErode` and `MPSDilate`.
enum MPSMorphologyOptions
{
    /// Width and height of the square structuring element when no size is given.
    static let DefaultSize = 3

    /// Gets the structuring element size from filter options.
    /// - Parameter Options: Dictionary with at most one key (the value is ignored).
    ///   - "SIZE3": 3x3 element.
    ///   - "SIZE5": 5x5 element.
    ///   - "SIZE7": 7x7 element.
    /// - Returns: The size, or `DefaultSize` if no recognized key is present.
    static func Size(From Options: [String: Any]?) -> Int
    {
        guard let Options = Options else
        {
            return DefaultSize
        }
        for Size in [3, 5, 7]
        {
            if Options["SIZE\(Size)"] != nil
            {
                return Size
            }
        }
        return DefaultSize
    }
}
