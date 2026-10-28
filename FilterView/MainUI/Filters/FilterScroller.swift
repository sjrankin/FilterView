//
//  FilterScroller.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import SwiftUI

struct FilterScroller: View
{
    @State var Server: FilterServer?
    @Binding var Selected: String?
    @State var SourceImage: Image? = nil

    var body: some View
    {
        if let Server = Server,
           let Source = SourceImage
        {
            if Server.BuiltInFilters.count > 0
            {
                ScrollView(.horizontal)
                {
                    HStack
                    {
                        ForEach(Server.GetFilterList(), id: \.self)
                        {
                            FilterName in
                            Button
                            {
                                Selected = FilterName
                            }
                            label:
                            {
                                FilterView(DisplayImage: Source,
                                           Server: Server,
                                           Filter: FilterName,
                                           IsSelected: Selected == FilterName)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 124)
                .background(.gray)
            }
        }
        else
        {
            ContentUnavailableView("No filter server available.", systemImage: "camera.filters")
        }
    }
}

#Preview
{
    @Previewable @State var Selected: String? = nil
    FilterScroller(Server: FilterServer(), Selected: $Selected)
        .frame(width: 300, height: 150)
}
