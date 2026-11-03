//
//  FilterParameterRow.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import SwiftUI

/// The control for one filter parameter. It starts from the saved value, saves each change, and tells its parent about it.
struct FilterParameterRow: View
{
    let Filter: String
    let Parameter: FilterParameter
    /// Called with the new value, as text, after it has been saved.
    let OnChange: (String) -> Void
    /// The value as text: a number, `true` or `false`, hex color, or the value of a choice.
    @State private var Current: String
    /// The value of a slider, which changes as it is dragged.
    @State private var Dragged: Double
    /// What the slider's text box shows and the user types in.
    @State private var ValueText: String
    @FocusState private var IsTyping: Bool
    @Environment(\.self) private var Environment

    init(Filter: String, Parameter: FilterParameter, OnChange: @escaping (String) -> Void)
    {
        self.Filter = Filter
        self.Parameter = Parameter
        self.OnChange = OnChange
        let Saved = FilterOptionStore.Shared.Value(Filter: Filter, Parameter: Parameter)
        _Current = State(initialValue: Saved)
        let Start = Double(Saved) ?? Double(Parameter.Default) ?? 0
        _Dragged = State(initialValue: Start)
        _ValueText = State(initialValue: Self.Formatted(Start))
    }

    var body: some View
    {
        switch Parameter.Kind
        {
            case .Slider:
                HStack
                {
                    Text(Parameter.Title)
                        .lineLimit(2)
                        .frame(width: 84, alignment: .leading)
                    // No `step` here: a stepped slider draws tick marks. The value is snapped to the step in `Snapped` instead.
                    Slider(value: $Dragged, in: SliderRange)
                    TextField(Parameter.Title, text: $ValueText)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(width: 56)
                        .focused($IsTyping)
                        .onSubmit(EnterTypedValue)
                }
                .onChange(of: Dragged)
                {
                    _, NewValue in
                    // The filter runs on every change, so the image follows the slider as it moves.
                    let Value = Snapped(NewValue)
                    if Value != NewValue
                    {
                        Dragged = Value
                    }
                    else
                    {
                        ValueText = Self.Formatted(Value)
                        if "\(Value)" != Current
                        {
                            Commit("\(Value)")
                        }
                    }
                }
                .onChange(of: IsTyping)
                {
                    _, Typing in
                    if !Typing
                    {
                        EnterTypedValue()
                    }
                }

            case .Toggle:
                Toggle(Parameter.Title, isOn: Binding(get: {Current == "true"}, set: {Commit($0 ? "true" : "false")}))

            case .Color:
                ColorPicker(Parameter.Title,
                            selection: Binding(get: {Color(Hex: Current) ?? .clear},
                                               set: {Commit($0.HexString(in: Environment))}),
                            supportsOpacity: true)

            case .Choice:
                Picker(Parameter.Title, selection: Binding(get: {Current}, set: {Commit($0)}))
                {
                    ForEach(Parameter.Choices ?? [], id: \.Value)
                    {
                        Choice in
                        Text(Choice.Title).tag(Choice.Value)
                    }
                }

            case .Text:
                HStack(alignment: .firstTextBaseline)
                {
                    Text(Parameter.Title)
                        .lineLimit(2)
                        .frame(width: 84, alignment: .leading)
                    // The filter runs as the text changes, like the sliders.
                    TextField(Parameter.Title, text: Binding(get: {Current}, set: {Commit($0)}), axis: .vertical)
                        .labelsHidden()
                        .lineLimit(1 ... 4)
                        .textFieldStyle(.roundedBorder)
                }

            case .Segments:
                VStack(alignment: .leading)
                {
                    Text(Parameter.Title)
                    // Long titles make a segmented control wider than the panel and push the layout out of shape, so those
                    // choices go in a menu.
                    if (Parameter.Choices ?? []).reduce(0, { $0 + $1.Title.count }) > 24
                    {
                        Picker(Parameter.Title, selection: Binding(get: {Current}, set: {Commit($0)}))
                        {
                            ForEach(Parameter.Choices ?? [], id: \.Value)
                            {
                                Choice in
                                Text(Choice.Title).tag(Choice.Value)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    else
                    {
                        Picker(Parameter.Title, selection: Binding(get: {Current}, set: {Commit($0)}))
                        {
                            ForEach(Parameter.Choices ?? [], id: \.Value)
                            {
                                Choice in
                                Text(Choice.Title).tag(Choice.Value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
        }
    }

    /// A slider value as text, without a thousands separator and with at most three decimals.
    private static func Formatted(_ Value: Double) -> String
    {
        Value.formatted(.number.precision(.fractionLength(0 ... 3)).grouping(.never))
    }

    /// Uses what was typed in the text box: a number is moved to the nearest value the slider allows (its limits, and its steps),
    /// and the slider and filter follow. Anything that is not a number is dropped and the current value shown again.
    private func EnterTypedValue()
    {
        let Cleaned = ValueText.trimmingCharacters(in: .whitespaces).replacing(",", with: ".")
        if let Typed = Double(Cleaned),
           Typed.isFinite
        {
            Dragged = Snapped(Typed)
        }
        ValueText = Self.Formatted(Dragged)
    }

    /// The values a slider covers. A missing or empty range is 0 to 1.
    private var SliderRange: ClosedRange<Double>
    {
        let Low = Parameter.Min ?? 0
        let High = Parameter.Max ?? 1
        return High > Low ? Low ... High : 0 ... 1
    }

    private var SliderStep: Double
    {
        Parameter.Step ?? (SliderRange.upperBound - SliderRange.lowerBound) / 100
    }

    /// The value moved to the nearest step of the slider, and rounded to remove the noise that division leaves.
    private func Snapped(_ Value: Double) -> Double
    {
        let Low = SliderRange.lowerBound
        let OnStep = Low + ((Value - Low) / SliderStep).rounded() * SliderStep
        return Rounded(min(max(OnStep, Low), SliderRange.upperBound))
    }

    /// Rounds away the noise that dragging a slider leaves in a number, so it is saved as 0.3 and not 0.30000000000000004.
    private func Rounded(_ Value: Double) -> Double
    {
        (Value * 10000).rounded() / 10000
    }

    /// Saves the value, shows it, and passes it on.
    private func Commit(_ Value: String)
    {
        Current = Value
        FilterOptionStore.Shared.Save(Filter: Filter, Key: Parameter.Key, Value: Value)
        OnChange(Value)
    }
}
