//
//  ControlStrip.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
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
