//
//  MainUI+Recording.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/31/26.
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
        await Recorder.Begin(Background: AppSettings.Shared.ImageBackground)
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

    /// Saves the newest live video frame, as filtered by the running filter, as a PNG. `LiveImage` already has the filter
    /// applied, so the saved frame is what is on screen.
    func SaveLiveFrame()
    {
        guard let Frame = LiveImage,
              let Result = ImageUtility.ImageToCGImage(Frame),
              let Encoded = ImageUtility.ImageEncoder.PNGData(Result) else
        {
            return
        }
        ExportDocument = ImageUtility.PNGImage(Data: Encoded)
        ShowExporter = true
    }
}
