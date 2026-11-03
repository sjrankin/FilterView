//
//  FilterTreeLoader.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
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
            let Tree = try JSONDecoder().decode(FilterNode.self, from: Raw)
            // Parts meant for another platform (the OpenCV filters are macOS only) are left out.
            return Tree.ForCurrentPlatform() ?? Tree
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
