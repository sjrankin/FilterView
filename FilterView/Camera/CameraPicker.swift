//
//  CameraPicker.swift
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

#if os(iOS)
import SwiftUI
import UIKit

/// The system camera. Shows the iOS camera interface, and returns the photo when the user accepts it.
/// - Note: SwiftUI has no camera view, so this wraps `UIImagePickerController`.
struct CameraPicker: UIViewControllerRepresentable
{
    /// Called when the camera closes, with the photo or `nil` if the user cancelled.
    let OnFinished: (CGImage?) -> Void

    /// True if this device has a camera. The iOS Simulator does not.
    static var IsAvailable: Bool
    {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController
    {
        let Picker = UIImagePickerController()
        Picker.sourceType = .camera
        Picker.delegate = context.coordinator
        return Picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context)
    {
    }

    func makeCoordinator() -> Coordinator
    {
        Coordinator(OnFinished: OnFinished)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate
    {
        let OnFinished: (CGImage?) -> Void

        init(OnFinished: @escaping (CGImage?) -> Void)
        {
            self.OnFinished = OnFinished
        }

        func imagePickerController(_ Picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo Info: [UIImagePickerController.InfoKey: Any])
        {
            guard let Photo = Info[.originalImage] as? UIImage else
            {
                OnFinished(nil)
                return
            }
            // A camera photo is stored sideways with an orientation flag, which a `CGImage` does not carry. Drawing it
            // applies the orientation so the result is upright.
            let Format = UIGraphicsImageRendererFormat()
            Format.scale = Photo.scale
            let Upright = UIGraphicsImageRenderer(size: Photo.size, format: Format).image
            {
                _ in
                Photo.draw(at: .zero)
            }
            OnFinished(Upright.cgImage)
        }

        func imagePickerControllerDidCancel(_ Picker: UIImagePickerController)
        {
            OnFinished(nil)
        }
    }
}
#endif
