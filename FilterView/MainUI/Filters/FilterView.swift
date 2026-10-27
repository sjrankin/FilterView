//
//  FilterView.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import SwiftUI

struct FilterView: View
{
    @State var SampleImage: Image
    @State var FilterName: String
    
    var body: some View
    {
        VStack
        {
            SampleImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(.white)
            HStack
            {
                Spacer()
                Text(FilterName)
                Spacer()
            }
        }
    }
}

#Preview
{
    let sample = Image(systemName: "camera.macro")
    FilterView(SampleImage: sample, FilterName: "Mesh")
}
