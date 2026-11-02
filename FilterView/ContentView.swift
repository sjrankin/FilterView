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
    @State var Filters: FilterNode? = nil
    @State private var LoadError: String? = nil

    var body: some View
    {
        VStack
        {
            if let LoadError = LoadError
            {
                ContentUnavailableView("Filters Unavailable",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text(LoadError))
            }
            else
            {
                MainUI(Filters: $Server,
                       FilterTreeData: Filters)
            }
        }
        .frame(minWidth: 320, minHeight: 400)
        .task
        {
            do
            {
                Filters = try FilterTreeLoader.Load(Resource: "FilterTree")
            }
            catch let Failure as FilterException
            {
                LoadError = Failure.Message
            }
            catch
            {
                LoadError = error.localizedDescription
            }
        }
    }
}

#Preview
{
    ContentView()
        .environment(PipelineModel())
}

