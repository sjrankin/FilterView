//
//  ContentView.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
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

