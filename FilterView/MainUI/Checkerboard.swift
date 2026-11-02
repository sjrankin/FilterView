//
//  Checkerboard.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
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
