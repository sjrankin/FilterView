//
//  FilterView.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import SwiftUI

struct FilterView: View
{
    @State var DisplayImage: Image
    var Server: FilterServer? = nil
    var Filter: String? = nil
    @State private var FilteredImage: Image? = nil
    let IsSelected: Bool

    var body: some View
    {
        VStack
        {
            if let ProcessedImage = FilteredImage
            {
                ProcessedImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.white)
            }
            else
            {
                Image("ProcessError")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.white)
            }
            HStack
            {
                Spacer()
                Text(Filter ?? "Generic")
                Spacer()
            }
        }
        .help("\(Filter ?? "Generic") filter to apply to the image.")
        .frame(maxWidth: 100)
        .background(IsSelected ? Color.yellow : Color.clear, in: .rect(cornerRadius: 8))
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
    let Source = Image("Hana")
    let FilterName = CILineScreen.FilterName
    FilterView(DisplayImage: Source,
               Server: FilterServer(),
               Filter: FilterName,
               IsSelected: false)
}
