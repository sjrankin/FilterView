//
//  ControlStack.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

import SwiftUI

struct ControlStack: View
{
    var FilterTreeData: FilterNode? = nil
    @Binding var Selection: FilterSelection?

    var body: some View
    {
        VStack(alignment: .leading)
        {
            FilterTreeView(Root: FilterTreeData, Selection: $Selection)
            Divider()
            OptionView()
                .frame(minHeight: 200)
        }
    }
}

#Preview
{
    @Previewable @State var Selected: FilterSelection? = nil
    ControlStack(Selection: $Selected)
}
