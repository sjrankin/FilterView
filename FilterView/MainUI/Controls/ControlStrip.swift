//
//  ControlStrip.swift
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

struct ControlStrip: View
{
    var body: some View
    {
        ScrollView(.horizontal)
        {
            HStack
            {
                Text("Input")
                    .bold()
                    .foregroundStyle(.blue)
                    .fixedSize()
                    .rotationEffect(Angle(degrees: 270.0))
                    .frame(width: 20)

                Button
                {
                    //action
                } label: {
                    VStack(alignment: .center)
                    {
                        Image(systemName: "camera")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.black)
                        Text("Photo")
                    }
                }
                
                Button
                {
                    //action
                } label: {
                    VStack(alignment: .center)
                    {
                        Image(systemName: "video")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.black)
                        Text("Live")
                    }
                }
                
                Button
                {
                    //action
                } label: {
                    VStack(alignment: .center)
                    {
                        Image(systemName: "photo")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.black)
                        Text("Library")
                    }
                }
                
                Divider()
                
                Text("Composite")
                    .bold()
                    .foregroundStyle(.blue)
                    .fixedSize()
                    .rotationEffect(Angle(degrees: 270.0))
                    .frame(width: 20)
                
                Button
                {
                    //action
                } label: {
                    VStack(alignment: .center)
                    {
                        Image(systemName: "rectangle")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.black)
                        Text("Full")
                    }
                }
                
                Button
                {
                    //action
                } label: {
                    VStack(alignment: .center)
                    {
                        Image(systemName: "rectangle.split.2x1")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.black)
                        Text("Left/Right")
                    }
                }
                
                Button
                {
                    //action
                } label: {
                    VStack(alignment: .center)
                    {
                        Image(systemName: "rectangle.split.1x2")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.black)
                        Text("Top/Bottom")
                    }
                }
                
                Divider()
                
                Text("Filters")
                    .bold()
                    .foregroundStyle(.blue)
                    .fixedSize()
                    .rotationEffect(Angle(degrees: 270.0))
                    .frame(width: 20)
                
                Text("CI Grayscale")
                
                Text("CI Halftone")
            }
        }
    }
}

#Preview
{
    ControlStrip()
}
