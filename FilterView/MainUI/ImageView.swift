//
//  ImageView.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import SwiftUI

struct ImageView: View
{
    /// The image to filter. A plain property (not `@State`) so a new image from the parent replaces it.
    var DisplayImage: Image
    var Server: FilterServer? = nil
    var Selection: FilterSelection? = nil
    /// Changes whenever the parent supplies a different image, which restarts the filter task.
    var SourceID = UUID()
    @State private var FilteredImage: Image?
    /// The `SourceID` that `FilteredImage` was made from. A result for an older image is never shown.
    @State private var FilteredFor: UUID?

    var body: some View
    {
        VStack
        {
            ((FilteredFor == SourceID ? FilteredImage : nil) ?? DisplayImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black, ignoresSafeAreaEdges: [])
        .task(id: TaskKey(Selection: Selection, SourceID: SourceID))
        {
            let Current = SourceID
            guard let Selection = Selection else
            {
                FilteredImage = nil
                return
            }
            do
            {
                let Result = try await DisplayImage.Filtered(Filter: Selection.Filter,
                                                             Server: Server,
                                                             Options: Selection.Options)
                if !Task.isCancelled
                {
                    FilteredImage = Result
                    FilteredFor = Current
                }
            }
            catch
            {
                FilteredImage = nil
            }
        }
    }
}

/// Identifies one filtering job: re-run when either the filter or the source image changes.
private struct TaskKey: Hashable
{
    let Selection: FilterSelection?
    let SourceID: UUID
}

#Preview
{
    ImageView(DisplayImage: Image("Hana"), Server: FilterServer())
}
