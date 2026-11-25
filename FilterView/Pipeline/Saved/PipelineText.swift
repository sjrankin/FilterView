//
//  PipelineText.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/23/26.
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

/// Converts a saved pipeline to and from a short, line-based text that is easy to edit in any text editor.
///
/// ```
/// pipeline "Line Art"
/// stage 1 filter "Regional Conditional" from 0
///     FILTER = "CI LineScreen"
///     REMOVE = true
/// stage 2 merge from 1 with 0 mode Multiply amount 1.0
/// final 2
/// ```
///
/// - A line starting with `#` is a comment, and blank lines are ignored. Indentation does not matter.
/// - `pipeline "Name"` starts a pipeline.
/// - `stage N KIND …` makes stage N. The kinds are `filter "Filter Name"`, `pass` (does nothing), `merge`, `split`, `join` and `nested`.
///   After the kind come, in any order: `from N` (the stage whose image it takes), `with N` (a merge's second image), `mode X` and
///   `amount X` (a merge), `layout X` (split and join), `regions N N …` (a join), `display "Name"` (the label of a filter, if it
///   differs from the filter's name), `under` and `skipped`.
/// - `KEY = value` lines under a filter stage are its options. Values with spaces or odd characters go in double quotes; inside quotes,
///   `\"`, `\\`, `\n` and `\t` stand for a quote, a backslash, a new line and a tab.
/// - A `nested` stage is followed by a full `pipeline …` that runs as the stage's filter, and ends with `end`.
/// - `final N` names the stage whose image is the result.
///
/// The controls of a filter (`SavedStage.Parameters`) are not part of the text; they come from the filter tree when the pipeline loads.
enum PipelineText
{
    // MARK: Writing

    /// The pipeline as text.
    /// - Parameter Pipeline: The pipeline.
    /// - Returns: The text, ending with a new line.
    static func Format(_ Pipeline: SavedPipeline) -> String
    {
        Lines(for: Pipeline).joined(separator: "\n") + "\n"
    }

    /// The lines that describe a pipeline, without indentation for the pipeline itself.
    private static func Lines(for Pipeline: SavedPipeline) -> [String]
    {
        var Result = ["pipeline \(Written(Pipeline.Name))"]
        for Stage in Pipeline.Stages.sorted(by: {$0.ID < $1.ID})
        {
            Result.append("")
            Result.append(StageLine(Stage))
            if let Nested = Stage.Nested
            {
                Result.append(contentsOf: Lines(for: Nested).map{$0.isEmpty ? $0 : "    " + $0})
                Result.append("    end")
            }
            else if let Options = Stage.Options
            {
                for Key in Options.keys.sorted()
                {
                    Result.append("    \(Written(Key)) = \(Written(Options[Key] ?? ""))")
                }
            }
        }
        Result.append("")
        Result.append("final \(Pipeline.FinalStage)")
        return Result
    }

    /// The `stage` line of a stage.
    private static func StageLine(_ Stage: SavedStage) -> String
    {
        var Words = ["stage", String(Stage.ID)]
        switch Stage.Kind
        {
            case .Filter:
                if Stage.Nested != nil
                {
                    Words.append("nested")
                }
                else if let Filter = Stage.Filter
                {
                    Words.append("filter")
                    Words.append(Written(Filter))
                }
                else
                {
                    Words.append("pass")
                }

            case .Merge:
                Words.append("merge")

            case .Split:
                Words.append("split")

            case .Join:
                Words.append("join")
        }
        Words.append(contentsOf: ["from", String(Stage.Input)])
        if let Second = Stage.Second
        {
            Words.append(contentsOf: ["with", String(Second)])
        }
        if Stage.Kind == .Merge
        {
            Words.append(contentsOf: ["mode", Written(Stage.MergeMode ?? "Multiply")])
            Words.append(contentsOf: ["amount", String(Stage.MergeAmount ?? 1.0)])
        }
        if let Layout = Stage.Layout
        {
            Words.append(contentsOf: ["layout", Written(Layout)])
        }
        if let Regions = Stage.Regions, Stage.Kind == .Join
        {
            Words.append("regions")
            Words.append(contentsOf: Regions.map{String($0)})
        }
        if Stage.Kind == .Filter, Stage.Nested == nil, let Display = Stage.DisplayName, Display != Stage.Filter
        {
            Words.append(contentsOf: ["display", Written(Display)])
        }
        if Stage.Under
        {
            Words.append("under")
        }
        if Stage.Skipped
        {
            Words.append("skipped")
        }
        return Words.joined(separator: " ")
    }

    /// Characters a word may hold without being put in quotes.
    private static let PlainCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-+/:"))

    /// A word as it is written: as it is if it is plain, otherwise in double quotes.
    private static func Written(_ Text: String) -> String
    {
        if !Text.isEmpty, Text.unicodeScalars.allSatisfy({PlainCharacters.contains($0)})
        {
            return Text
        }
        var Escaped = ""
        for Letter in Text
        {
            switch Letter
            {
                case "\"":
                    Escaped += "\\\""

                case "\\":
                    Escaped += "\\\\"

                case "\n":
                    Escaped += "\\n"

                case "\t":
                    Escaped += "\\t"

                default:
                    Escaped.append(Letter)
            }
        }
        return "\"" + Escaped + "\""
    }

    // MARK: Reading

    /// One word of a line.
    private struct Word
    {
        let Text: String
        /// True if it was in double quotes, which makes it text even if it looks like a keyword or `=`.
        let IsQuoted: Bool
    }

    /// A line that is not blank or a comment, split into words.
    private struct Line
    {
        /// The line's number in the text, from 1.
        let Number: Int
        let Words: [Word]
    }

    private static func Failure(_ Number: Int, _ Message: String) -> FilterException
    {
        FilterException(Message: "Line \(Number): \(Message)")
    }

    /// Splits a line into words.
    private static func Split(_ Text: String, Number: Int) throws -> [Word]
    {
        var Found = [Word]()
        let Letters = Array(Text)
        var Index = 0
        while Index < Letters.count
        {
            if Letters[Index].isWhitespace
            {
                Index += 1
            }
            else if Letters[Index] == "\""
            {
                Index += 1
                var Made = ""
                var Closed = false
                while Index < Letters.count
                {
                    let Letter = Letters[Index]
                    if Letter == "\\", Index + 1 < Letters.count
                    {
                        switch Letters[Index + 1]
                        {
                            case "n":
                                Made.append("\n")

                            case "t":
                                Made.append("\t")

                            default:
                                Made.append(Letters[Index + 1])
                        }
                        Index += 2
                    }
                    else if Letter == "\""
                    {
                        Closed = true
                        Index += 1
                        break
                    }
                    else
                    {
                        Made.append(Letter)
                        Index += 1
                    }
                }
                guard Closed else
                {
                    throw Failure(Number, "A quote is not closed.")
                }
                Found.append(Word(Text: Made, IsQuoted: true))
            }
            else
            {
                var Made = ""
                while Index < Letters.count, !Letters[Index].isWhitespace
                {
                    Made.append(Letters[Index])
                    Index += 1
                }
                Found.append(Word(Text: Made, IsQuoted: false))
            }
        }
        return Found
    }

    /// Reads a pipeline from text.
    /// - Parameter Text: The text, as `Format` makes it.
    /// - Returns: The pipeline.
    /// - Throws: `FilterException` saying what is wrong, and on which line.
    static func Parse(_ Text: String) throws -> SavedPipeline
    {
        var Kept = [Line]()
        for (Index, Raw) in Text.components(separatedBy: .newlines).enumerated()
        {
            let Trimmed = Raw.trimmingCharacters(in: .whitespaces)
            if Trimmed.isEmpty || Trimmed.hasPrefix("#")
            {
                continue
            }
            Kept.append(Line(Number: Index + 1, Words: try Split(Trimmed, Number: Index + 1)))
        }
        var Position = 0
        let Result = try ParsePipeline(Kept, &Position, IsNested: false)
        if Position < Kept.count
        {
            throw Failure(Kept[Position].Number, "Nothing may come after the pipeline. Did you mean to put it in a nested stage?")
        }
        return Result
    }

    /// Reads one pipeline, starting at its `pipeline` line.
    private static func ParsePipeline(_ Lines: [Line], _ Position: inout Int, IsNested: Bool) throws -> SavedPipeline
    {
        guard Position < Lines.count else
        {
            throw FilterException(Message: "The text holds no pipeline. It must start with: pipeline \"Name\"")
        }
        let Header = Lines[Position]
        guard Header.Words.count == 2, Header.Words[0].Text == "pipeline", !Header.Words[0].IsQuoted else
        {
            throw Failure(Header.Number, "A pipeline starts with: pipeline \"Name\"")
        }
        let Name = Header.Words[1].Text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !Name.isEmpty else
        {
            throw Failure(Header.Number, "The pipeline needs a name.")
        }
        Position += 1

        var Stages = [SavedStage]()
        var Final: Int? = nil
        var Ended = false
        while Position < Lines.count, !Ended
        {
            let Current = Lines[Position]
            let First = Current.Words[0]
            if Current.Words.count == 3, Current.Words[1].Text == "=", !Current.Words[1].IsQuoted
            {
                guard var Last = Stages.last, Last.Kind == .Filter, Last.Filter != nil, Last.Nested == nil else
                {
                    throw Failure(Current.Number, "Options belong under a filter stage.")
                }
                var Options = Last.Options ?? [:]
                Options[First.Text] = Current.Words[2].Text
                Last.Options = Options
                Stages[Stages.count - 1] = Last
                Position += 1
            }
            else if !First.IsQuoted, First.Text == "stage"
            {
                var Made = try ParseStage(Current)
                Position += 1
                if Made.Kind == .Filter, Made.Filter == SavedPipelineFilter.FilterName, Made.DisplayName == nil
                {
                    // A nested stage: a whole pipeline follows, up to its end.
                    let Inner = try ParsePipeline(Lines, &Position, IsNested: true)
                    Made.Nested = Inner
                    Made.DisplayName = Inner.Name
                }
                if Stages.contains(where: {$0.ID == Made.ID})
                {
                    throw Failure(Current.Number, "There are two stages numbered \(Made.ID).")
                }
                Stages.append(Made)
            }
            else if !First.IsQuoted, First.Text == "final"
            {
                guard Current.Words.count == 2, let Number = Int(Current.Words[1].Text), Number >= 0 else
                {
                    throw Failure(Current.Number, "Write the final stage as: final N")
                }
                Final = Number
                Position += 1
            }
            else if !First.IsQuoted, First.Text == "end"
            {
                guard IsNested else
                {
                    throw Failure(Current.Number, "This 'end' has no nested stage to end.")
                }
                Ended = true
                Position += 1
            }
            else
            {
                throw Failure(Current.Number, "Cannot understand “\(First.Text)”.")
            }
        }
        if IsNested, !Ended
        {
            throw FilterException(Message: "The nested pipeline “\(Name)” has no 'end'.")
        }
        try Check(Stages, Final: Final, Name: Name, Line: Header.Number)
        return SavedPipeline(Name: Name, Stages: Stages, FinalStage: Final ?? Stages.map{$0.ID}.max() ?? 0)
    }

    /// Makes a stage from its `stage` line. A nested stage comes back marked with the nested filter's name and no nested pipeline yet.
    private static func ParseStage(_ Current: Line) throws -> SavedStage
    {
        let Words = Current.Words.map{$0.Text}
        let Number = Current.Number
        guard Words.count >= 4, let ID = Int(Words[1]), ID >= 1 else
        {
            throw Failure(Number, "Write a stage as: stage N KIND from N …, with N 1 or more.")
        }
        var Made = SavedStage(ID: ID, Kind: .Filter, Input: 0, Second: nil, Under: false, Skipped: false)
        var Position = 3
        switch Words[2]
        {
            case "filter":
                guard Words.count > 4 else
                {
                    throw Failure(Number, "A filter stage needs the filter's name.")
                }
                Made.Filter = Words[3]
                Position = 4

            case "pass":
                break

            case "nested":
                Made.Filter = SavedPipelineFilter.FilterName

            case "merge":
                Made.Kind = .Merge
                Made.MergeMode = MergeModes.Multiply.rawValue
                Made.MergeAmount = 1.0

            case "split":
                Made.Kind = .Split

            case "join":
                Made.Kind = .Join
                Made.Regions = []

            default:
                throw Failure(Number, "“\(Words[2])” is not a kind of stage. Use filter, pass, merge, split, join or nested.")
        }
        var HasFrom = false
        var Display: String? = nil
        while Position < Words.count
        {
            let Keyword = Words[Position]
            Position += 1
            /// The word after the keyword.
            func Argument() throws -> String
            {
                guard Position < Words.count else
                {
                    throw Failure(Number, "“\(Keyword)” needs a value after it.")
                }
                Position += 1
                return Words[Position - 1]
            }
            /// The word after the keyword, as a stage number.
            func StageNumber() throws -> Int
            {
                let Value = try Argument()
                guard let Found = Int(Value), Found >= 0 else
                {
                    throw Failure(Number, "“\(Value)” is not a stage number.")
                }
                return Found
            }
            switch Keyword
            {
                case "from":
                    Made.Input = try StageNumber()
                    HasFrom = true

                case "with":
                    guard Made.Kind == .Merge else
                    {
                        throw Failure(Number, "Only a merge has a second image (“with”).")
                    }
                    Made.Second = try StageNumber()

                case "mode":
                    guard Made.Kind == .Merge else
                    {
                        throw Failure(Number, "Only a merge has a mode.")
                    }
                    let Mode = try Argument()
                    guard MergeModes(rawValue: Mode) != nil else
                    {
                        throw Failure(Number, "“\(Mode)” is not a merge mode. Use one of: "
                                      + MergeModes.allCases.map{$0.rawValue}.joined(separator: ", ") + ".")
                    }
                    Made.MergeMode = Mode

                case "amount":
                    guard Made.Kind == .Merge else
                    {
                        throw Failure(Number, "Only a merge has an amount.")
                    }
                    let Amount = try Argument()
                    guard let Value = Double(Amount) else
                    {
                        throw Failure(Number, "“\(Amount)” is not a number.")
                    }
                    Made.MergeAmount = Value

                case "layout":
                    guard Made.Kind == .Split || Made.Kind == .Join else
                    {
                        throw Failure(Number, "Only a split or a join has a layout.")
                    }
                    let Layout = try Argument()
                    guard SplitLayouts(rawValue: Layout) != nil else
                    {
                        throw Failure(Number, "“\(Layout)” is not a layout. Use one of: "
                                      + SplitLayouts.allCases.map{$0.rawValue}.joined(separator: ", ") + ".")
                    }
                    Made.Layout = Layout

                case "regions":
                    guard Made.Kind == .Join else
                    {
                        throw Failure(Number, "Only a join has regions.")
                    }
                    var Found = [Int]()
                    while Position < Words.count, let Next = Int(Words[Position])
                    {
                        Found.append(Next)
                        Position += 1
                    }
                    Made.Regions = Found

                case "display":
                    Display = try Argument()

                case "under":
                    Made.Under = true

                case "skipped":
                    Made.Skipped = true

                default:
                    throw Failure(Number, "Cannot understand “\(Keyword)” in a stage.")
            }
        }
        guard HasFrom else
        {
            throw Failure(Number, "Stage \(ID) needs to say which stage it takes its image from: from N")
        }
        if Made.Kind == .Merge, Made.Second == nil
        {
            throw Failure(Number, "A merge needs a second image: with N")
        }
        if Made.Kind == .Split || Made.Kind == .Join, Made.Layout == nil
        {
            throw Failure(Number, "A split or join needs a layout: layout 2x1, 1x2 or 2x2")
        }
        if Made.Kind == .Filter, Made.Filter != nil, Made.Filter != SavedPipelineFilter.FilterName
        {
            Made.DisplayName = Display ?? Made.Filter
        }
        return Made
    }

    /// Makes sure the stages refer to stages that exist and do not lead back to themselves.
    private static func Check(_ Stages: [SavedStage], Final: Int?, Name: String, Line: Int) throws
    {
        let IDs = Set(Stages.map{$0.ID})
        func Exists(_ ID: Int) -> Bool
        {
            ID == 0 || IDs.contains(ID)
        }
        for Stage in Stages
        {
            let Needed = [Stage.Input] + (Stage.Second.map{[$0]} ?? []) + (Stage.Regions ?? [])
            if let Missing = Needed.first(where: {!Exists($0)})
            {
                throw FilterException(Message: "Stage \(Stage.ID) of “\(Name)” refers to stage \(Missing), which does not exist.")
            }
        }
        if let Final, !Exists(Final)
        {
            throw FilterException(Message: "The final stage of “\(Name)” is \(Final), which does not exist.")
        }
        // Following the inputs back from any stage must reach the original image (0), never a stage already passed.
        var Inputs = [Int: [Int]]()
        for Stage in Stages
        {
            Inputs[Stage.ID] = [Stage.Input] + (Stage.Second.map{[$0]} ?? []) + (Stage.Regions ?? [])
        }
        var Done = Set<Int>()
        func Visit(_ ID: Int, _ Path: Set<Int>) throws
        {
            if ID == 0 || Done.contains(ID)
            {
                return
            }
            if Path.contains(ID)
            {
                throw FilterException(Message: "Stage \(ID) of “\(Name)” takes its own result as an input, through other stages.")
            }
            for Next in Inputs[ID] ?? []
            {
                try Visit(Next, Path.union([ID]))
            }
            Done.insert(ID)
        }
        for Stage in Stages
        {
            try Visit(Stage.ID, [])
        }
    }
}
