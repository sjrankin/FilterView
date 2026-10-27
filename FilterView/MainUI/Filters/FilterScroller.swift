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
    
    var body: some View
    {
        if let Server = Server
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
                            FilterView(SampleImage: Image(systemName: "camera"), FilterName: FilterName)
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
    FilterScroller(Server: FilterServer())
        .frame(width: 300, height: 150)
}
