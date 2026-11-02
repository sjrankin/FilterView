//
//  FilterOptionsView.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import SwiftUI

/// The options of the selected filter, one control for each parameter the filter tree lists for it. A change is saved and the
/// selection is replaced with one carrying the new value, which makes the image render again.
struct FilterOptionsView: View
{
    @Binding var Selection: FilterSelection?
    @State private var ConfirmReset = false
    /// Counts resets. The rows keep their own copy of a value, so they are made again after a reset to show the original ones.
    @State private var ResetCount = 0

    var body: some View
    {
        if let Current = Selection,
           !Current.Parameters.isEmpty
        {
            VStack(spacing: 0)
            {
                ScrollView
                {
                    VStack(alignment: .leading)
                    {
                        ForEach(Current.Parameters)
                        {
                            Parameter in
                            FilterParameterRow(Filter: Current.Filter, Parameter: Parameter)
                            {
                                Value in
                                Selection = Selection?.Updating(Key: Parameter.Key, Value: Value)
                            }
                        }
                    }
                    // Fill the width, so the rows start at the left edge and are not centered in the scroll view.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing)
                }
                // Visible so it is clear there is more to scroll to; it takes whatever room is left, but never less than a row or two.
                .scrollIndicators(.visible)
                .frame(minHeight: 60)
                // Entries that share a filter share parameter keys, so the rows start over when the entry changes.
                .id("\(Current.DisplayName) \(ResetCount)")
                // Outside the scroll view, so it is always in reach.
                Divider()
                HStack
                {
                    Spacer()
                    Button("Reset", role: .destructive)
                    {
                        ConfirmReset = true
                    }
                }
                .padding(.vertical, 6)
            }
            .confirmationDialog("Reset the options?", isPresented: $ConfirmReset)
            {
                Button("Reset", role: .destructive)
                {
                    ResetOptions(Current)
                }
                Button("Cancel", role: .cancel) {}
            }
            message:
            {
                Text("Every option of this filter goes back to its original setting.")
            }
        }
        else
        {
            Text("No options")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Puts every option of the selected filter back to its default, saves that, and renders the image again.
    private func ResetOptions(_ Current: FilterSelection)
    {
        var Changed = Current
        for Parameter in Current.Parameters
        {
            FilterOptionStore.Shared.Save(Filter: Current.Filter, Key: Parameter.Key, Value: Parameter.Default)
            Changed = Changed.Updating(Key: Parameter.Key, Value: Parameter.Default)
        }
        Selection = Changed
        ResetCount += 1
    }
}
