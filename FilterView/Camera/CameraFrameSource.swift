//
//  CameraFrameSource.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/31/26.
//

import Foundation
import AVFoundation
import VideoToolbox
import Synchronization
import CoreGraphics

/// Delivers live video frames from the device's camera as `CGImage`s.
///
/// Call `Frames()` to start the camera. The camera stops when the stream ends, which happens when the task that is
/// iterating the stream is cancelled.
final class CameraFrameSource: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable
{
    /// Maximum frames per second delivered. 0 means no limit. Can be changed while the camera is running.
    var MaxFPS: Double
    {
        get
        {
            MaxFPSLimit.withLock { $0 }
        }
        set
        {
            MaxFPSLimit.withLock { $0 = newValue }
        }
    }

    private let MaxFPSLimit = Mutex<Double>(0)

    private let Session = AVCaptureSession()
    /// AVFoundation delivers frames on a dispatch queue, so this cannot be a Swift concurrency construct.
    private let Queue = DispatchQueue(label: "FilterView.CameraFrames")
    private let LastFrameTime = Mutex<CMTime>(.invalid)
    /// While true the frames keep the orientation they have, so a recording (whose size is fixed by its first frame) is not
    /// disturbed by the device turning.
    var RotationLocked: Bool
    {
        get
        {
            RotationLock.withLock { $0 }
        }
        set
        {
            RotationLock.withLock { $0 = newValue }
        }
    }

    private let RotationLock = Mutex<Bool>(false)
    #if os(iOS)
    /// Says which way is up for the camera as the device turns. Set while the camera runs.
    nonisolated(unsafe) private var Rotation: AVCaptureDevice.RotationCoordinator? = nil
    #endif
    private let Sink = Mutex<AsyncStream<CGImage>.Continuation?>(nil)

    /// Starts the camera and returns its frames.
    /// - Returns: A stream of frames. It only holds the newest undelivered frame, so a slow consumer (a slow filter, for
    /// example) skips frames instead of falling behind.
    /// - Throws: `FilterException` if camera access is denied or there is no camera. The iOS Simulator has no camera.
    func Frames() async throws -> AsyncStream<CGImage>
    {
        guard await AVCaptureDevice.requestAccess(for: .video) else
        {
            throw FilterException(Message: "Camera access was denied")
        }
        guard let Camera = AVCaptureDevice.default(for: .video),
              let Input = try? AVCaptureDeviceInput(device: Camera) else
        {
            throw FilterException(Message: "No camera is available")
        }
        let Output = AVCaptureVideoDataOutput()
        Output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        // Frames that arrive while the delegate is still busy are dropped by AVFoundation.
        Output.alwaysDiscardsLateVideoFrames = true
        Output.setSampleBufferDelegate(self, queue: Queue)

        // Every change to the session is made on `Queue`, one at a time. A session cannot be started while another change is in
        // progress (that raises an exception), and the shutdown of the previous run is also on this queue, so this waits its turn
        // behind it. Making the changes here, on the caller's thread, could overlap that shutdown.
        nonisolated(unsafe) let NewInput = Input
        nonisolated(unsafe) let NewOutput = Output
        let Added = await withCheckedContinuation
        {
            (Continuation: CheckedContinuation<Bool, Never>) in
            Queue.async
            {
                self.Session.beginConfiguration()
                defer
                {
                    self.Session.commitConfiguration()
                }
                guard self.Session.canAddInput(NewInput),
                      self.Session.canAddOutput(NewOutput) else
                {
                    Continuation.resume(returning: false)
                    return
                }
                self.Session.addInput(NewInput)
                self.Session.addOutput(NewOutput)
                #if os(iOS)
                // Upright for the way the device is held now; `captureOutput` keeps it so as the device turns.
                let Coordinator = AVCaptureDevice.RotationCoordinator(device: Camera, previewLayer: nil)
                self.Rotation = Coordinator
                NewOutput.connection(with: .video)?.videoRotationAngle = Coordinator.videoRotationAngleForHorizonLevelCapture
                #endif
                Continuation.resume(returning: true)
            }
        }
        guard Added else
        {
            throw FilterException(Message: "Cannot start the camera")
        }
        LastFrameTime.withLock { $0 = .invalid }

        return AsyncStream(bufferingPolicy: .bufferingNewest(1))
        {
            Continuation in
            Sink.withLock { $0 = Continuation }
            Continuation.onTermination =
            {
                _ in
                // Starting and stopping a session blocks, so keep both off the caller's thread.
                self.Queue.async
                {
                    self.Session.stopRunning()
                    self.Session.beginConfiguration()
                    self.Session.inputs.forEach { self.Session.removeInput($0) }
                    self.Session.outputs.forEach { self.Session.removeOutput($0) }
                    self.Session.commitConfiguration()
                }
                self.Sink.withLock { $0 = nil }
            }
            Queue.async
            {
                self.Session.startRunning()
            }
        }
    }

    /// Called by AVFoundation for each camera frame. Applies the frame rate limit, then converts the frame to a `CGImage`.
    func captureOutput(_ Output: AVCaptureOutput, didOutput Buffer: CMSampleBuffer, from Connection: AVCaptureConnection)
    {
        let Limit = MaxFPS
        let Now = CMSampleBufferGetPresentationTimeStamp(Buffer)
        if Limit > 0
        {
            let Last = LastFrameTime.withLock { $0 }
            if Last.isValid,
               CMTimeGetSeconds(CMTimeSubtract(Now, Last)) < 1.0 / Limit
            {
                // Too soon after the last delivered frame. Dropped before the costly conversion.
                return
            }
        }
        #if os(iOS)
        if !RotationLocked,
           let Angle = Rotation?.videoRotationAngleForHorizonLevelCapture,
           Connection.videoRotationAngle != Angle,
           Connection.isVideoRotationAngleSupported(Angle)
        {
            // This frame still has the old angle; the next ones are turned.
            Connection.videoRotationAngle = Angle
        }
        #endif
        LastFrameTime.withLock { $0 = Now }
        guard let Pixels = CMSampleBufferGetImageBuffer(Buffer) else
        {
            return
        }
        var Frame: CGImage? = nil
        VTCreateCGImageFromCVPixelBuffer(Pixels, options: nil, imageOut: &Frame)
        if let Frame = Frame
        {
            Sink.withLock { $0 }?.yield(Frame)
        }
    }
}
