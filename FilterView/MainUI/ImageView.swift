//
//  ImageView.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import SwiftUI

struct ImageView: View
{
    @State var DisplayImage: Image
    var Server: FilterServer? = nil
    var Filter: String? = nil
    @State private var FilteredImage: Image?

    var body: some View
    {
        VStack
        {
            (FilteredImage ?? DisplayImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black, ignoresSafeAreaEdges: [])
        .task(id: Filter)
        {
            guard let Filter = Filter else
            {
                FilteredImage = nil
                return
            }
            do
            {
                var Parameters: [String: Any]? = nil
                if Filter == ConditionalMetalInvert.FilterName
                {
                    Parameters = [String: Any]()
                    Parameters![Channels.RedBlue.rawValue] = 0
                }
                if Filter == ChannelSwap.FilterName
                {
                    Parameters = [String: Any]()
                    Parameters![SwapChannels.RedBlue.rawValue] = 0
                }
                let Result = try await DisplayImage.Filtered(Filter: Filter,
                                                             Server: Server,
                                                             Options: Parameters)
                if !Task.isCancelled
                {
                    FilteredImage = Result
                }
            }
            catch
            {
                FilteredImage = nil
            }
        }
    }
}

#Preview
{
    ImageView(DisplayImage: Image("Hana"), Server: FilterServer())
}
