//
//  FilterOptionStore.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation

/// Remembers the values of filter parameters in `UserDefaults`. Entries are made as filters are used: a parameter with no saved
/// value gets its default saved the first time it is asked for, so new filters and new parameters need no setup.
/// - Note: Values belong to a filter and a key, not to a tree entry, so tree entries that share a filter share its values.
@MainActor
final class FilterOptionStore
{
    static let Shared = FilterOptionStore()

    private let Defaults: UserDefaults

    init(Defaults: UserDefaults = .standard)
    {
        self.Defaults = Defaults
    }

    /// The `UserDefaults` key for one parameter of one filter.
    static func DefaultsKey(Filter: String, Key: String) -> String
    {
        "FilterOption.\(Filter).\(Key)"
    }

    /// The saved value of a parameter. If there is none, the parameter's default is saved and returned.
    func Value(Filter: String, Parameter: FilterParameter) -> String
    {
        let Name = FilterOptionStore.DefaultsKey(Filter: Filter, Key: Parameter.Key)
        if let Saved = Defaults.string(forKey: Name)
        {
            return Saved
        }
        Defaults.set(Parameter.Default, forKey: Name)
        return Parameter.Default
    }

    /// Saves the value of a parameter.
    func Save(Filter: String, Key: String, Value: String)
    {
        Defaults.set(Value, forKey: FilterOptionStore.DefaultsKey(Filter: Filter, Key: Key))
    }

    /// The fixed options of a tree entry with the saved value of each of its parameters added. A saved value wins over a fixed
    /// option with the same key.
    /// - Returns: The options, or `nil` if there are none at all.
    func Merged(Filter: String, Fixed: [String: String]?, Parameters: [FilterParameter]) -> [String: String]?
    {
        var Result = Fixed ?? [:]
        for Parameter in Parameters
        {
            Result[Parameter.Key] = Value(Filter: Filter, Parameter: Parameter)
        }
        return Result.isEmpty ? nil : Result
    }
}
