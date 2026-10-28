//
//  MainUI.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import SwiftUI

struct MainUI: View
{
    @Binding var Filters: FilterServer?
    @State private var SelectedFilter: String? = nil
    var TestImage = Image("Hana")

    var body: some View
    {
        VStack
        {
            ImageView(DisplayImage: TestImage,
                      Server: Filters,
                      Filter: SelectedFilter)
                .frame(minHeight: 200)
            ControlStrip()
                .frame(height: 64)
            FilterScroller(Server: Filters,
                           Selected: $SelectedFilter,
                           SourceImage: TestImage)
                .frame(height: 130)
        }
    }
}

#Preview
{
    @Previewable @State var Filters: FilterServer? = FilterServer()
    MainUI(Filters: $Filters)
}
