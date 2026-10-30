//
//  FilterTreeLoader.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

import Foundation

/// Loads a tree of `FilterNode` from JSON.
enum FilterTreeLoader
{
    /// Decodes a tree from a JSON string.
    /// - Parameter JSON: The JSON text.
    /// - Returns: The root node.
    /// - Throws: `FilterException` if the text is not valid UTF-8 or does not match the expected structure.
    static func Load(JSON: String) throws -> FilterNode
    {
        guard let Raw = JSON.data(using: .utf8) else
        {
            throw FilterException(Message: "Filter tree JSON is not valid UTF-8")
        }
        return try Load(Data: Raw)
    }

    /// Decodes a tree from JSON data.
    /// - Parameter Data: The JSON data.
    /// - Returns: The root node.
    /// - Throws: `FilterException` if the data does not match the expected structure.
    static func Load(Data Raw: Data) throws -> FilterNode
    {
        do
        {
            return try JSONDecoder().decode(FilterNode.self, from: Raw)
        }
        catch
        {
            throw FilterException(Message: "Cannot decode filter tree: \(error)")
        }
    }

    /// Decodes a tree from a JSON file in the app bundle.
    /// - Parameter Resource: The file name without extension.
    /// - Parameter Bundle: The bundle holding the file.
    /// - Returns: The root node.
    /// - Throws: `FilterException` if the file is missing, unreadable, or malformed.
    static func Load(Resource: String, Bundle: Bundle = .main) throws -> FilterNode
    {
        guard let Location = Bundle.url(forResource: Resource, withExtension: "json") else
        {
            throw FilterException(Message: "Cannot find \(Resource).json in the bundle")
        }
        do
        {
            return try Load(Data: Data(contentsOf: Location))
        }
        catch let Failure as FilterException
        {
            throw Failure
        }
        catch
        {
            throw FilterException(Message: "Cannot read \(Resource).json: \(error)")
        }
    }

    /// Checks that every leaf names a filter the server knows about.
    /// - Parameter Root: The tree to check.
    /// - Parameter Server: The filter server.
    /// - Returns: Filter names in the tree that the server does not have. Empty if all are found.
    static func MissingFilters(in Root: FilterNode, Server: FilterServer) -> [String]
    {
        Root.Leaves().compactMap{$0.Filter}.filter{Server.GetFilter($0) == nil}
    }
}
