//
//  ContentView.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import SwiftUI

struct ContentView: View
{
    @State var Server: FilterServer? = FilterServer()
    
    var body: some View
    {
        MainUI(Filters: $Server)
            .frame(minWidth: 320, minHeight: 400)
    }
}

#Preview
{
    ContentView()
}

