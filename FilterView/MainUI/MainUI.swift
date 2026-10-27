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
    
    var body: some View
    {
        VStack
        {
            ImageView(DisplayImage: Image("Hana"),
                      Server: Filters)
                .frame(minHeight: 200)
            ControlStrip()
                .frame(height: 64)
            FilterScroller(Server: Filters)
                .frame(height: 130)
        }
    }
}

#Preview
{
    @Previewable @State var Filters: FilterServer? = FilterServer()
    MainUI(Filters: $Filters)
}
