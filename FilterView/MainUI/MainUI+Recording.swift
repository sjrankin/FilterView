//
//  MainUI+Recording.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/31/26.
//

import SwiftUI

extension MainUI
{
    /// Starts recording the filtered live video. Frames are added by `RunLiveVideo` while `IsRecording` is true.
    /// A new recording replaces the last one, so the last one's file is deleted.
    func StartRecording() async
    {
        if let Old = LastMovie
        {
            try? FileManager.default.removeItem(at: Old.File)
            LastMovie = nil
        }
        await Recorder.Begin()
        IsRecording = true
    }

    /// Stops recording, finishes the file, and asks the user where to save it.
    /// - Note: Also called when the input is changed from Video during a recording, so the video is not lost.
    func StopRecording() async
    {
        guard IsRecording else
        {
            return
        }
        IsRecording = false
        do
        {
            LastMovie = RecordedMovie(File: try await Recorder.Finish())
            ShowMovieExporter = true
        }
        catch
        {
            print("Recording failed: \(error)")
        }
    }
}
