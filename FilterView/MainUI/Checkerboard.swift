//
//  Checkerboard.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
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

/// A gray checkerboard, drawn behind images so transparent areas can be seen.
struct Checkerboard: View
{
    /// Width and height of each square, in points.
    var SquareSize: CGFloat = 10
    
    var body: some View
    {
        Canvas
        {
            Context, Size in
            Context.fill(Path(CGRect(origin: .zero, size: Size)), with: .color(white: 0.85))
            let Columns = Int((Size.width / SquareSize).rounded(.up))
            let Rows = Int((Size.height / SquareSize).rounded(.up))
            for Row in 0 ..< Rows
            {
                for Column in 0 ..< Columns where (Row + Column).isMultiple(of: 2)
                {
                    let Square = CGRect(x: CGFloat(Column) * SquareSize,
                                        y: CGFloat(Row) * SquareSize,
                                        width: SquareSize,
                                        height: SquareSize)
                    Context.fill(Path(Square), with: .color(white: 0.6))
                }
            }
        }
    }
}

#Preview
{
    Checkerboard()
}
