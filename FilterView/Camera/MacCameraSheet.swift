//
//  MacCameraSheet.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/31/26.
//

#if os(macOS)
import SwiftUI

/// A sheet for taking a photo with the Mac's camera: a live preview and a Take Photo button. macOS has no system camera
/// interface an app can use to get a photo back, so this is built on `CameraFrameSource`.
struct MacCameraSheet: View
{
    /// Called when the sheet closes, with the photo or `nil` if the user cancelled.
    let OnFinished: (CGImage?) -> Void
    @State private var Camera = CameraFrameSource()
    @State private var LatestFrame: CGImage? = nil
    @State private var Failure: String? = nil

    var body: some View
    {
        VStack
        {
            if let Failure = Failure
            {
                ContentUnavailableView("Camera Unavailable", systemImage: "video.slash", description: Text(Failure))
            }
            else if let LatestFrame = LatestFrame
            {
                ImageUtility.CGImageToImage(LatestFrame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            else
            {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack
            {
                Button("Cancel", role: .cancel)
                {
                    OnFinished(nil)
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Take Photo", systemImage: "camera")
                {
                    OnFinished(LatestFrame)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(LatestFrame == nil)
            }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 480)
        // The camera runs while the sheet is open. Closing the sheet cancels this task, which stops the camera.
        .task
        {
            Camera.MaxFPS = 30
            do
            {
                for await Frame in try await Camera.Frames()
                {
                    LatestFrame = Frame
                }
            }
            catch let Problem as FilterException
            {
                Failure = Problem.Message
            }
            catch
            {
                Failure = error.localizedDescription
            }
        }
    }
}
#endif
