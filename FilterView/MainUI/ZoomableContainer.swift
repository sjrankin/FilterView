//
//  ZoomableContainer.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
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
#if os(macOS)
import AppKit
#endif

/// Shows its content filling the available space, and lets the user zoom in on it, up to eight times, and move around it. At 100% the
/// content fits the space, as it did before, and there are no scroll bars. Zoom with the slider, the buttons, a pinch on a trackpad, or
/// the mouse wheel (macOS); the zoom stays centered on the pointer. Move around with the scroll bars or by dragging the image.
struct ZoomableContainer<Content: View>: View
{
    /// The most the content can be zoomed in.
    static var MaxZoom: Double { 8.0 }

    @ViewBuilder var Inner: () -> Content
    /// 1.0 is the content fitted to the space.
    @State private var Zoom = 1.0
    /// The zoom when the current pinch began.
    @State private var PinchStart: Double? = nil
    /// The size of the space the content is shown in.
    @State private var Viewport = CGSize.zero
    @State private var Position = ScrollPosition()
    /// How far the content is scrolled, and where the pointer is. Kept in a class that is not observed, because they change on every
    /// scroll and mouse move, and the view must not be drawn again each time.
    @State private var Tracker = ScrollTracker()
    /// The scroll offset when the current drag began.
    @State private var DragStart: CGPoint? = nil
    #if os(macOS)
    @State private var WheelWatcher = WheelZoomWatcher()
    #endif

    /// Keeps a zoom between fitted and the most allowed.
    static func Clamped(_ Value: Double) -> Double
    {
        min(max(Value, 1.0), MaxZoom)
    }

    /// Sets the zoom, keeping the point of the content under `Anchor` where it is.
    /// - Parameter Wanted: The zoom asked for.
    /// - Parameter Anchor: A point in the space the content is shown in. `nil` for its center.
    private func SetZoom(_ Wanted: Double, Anchor: CGPoint?)
    {
        let New = Self.Clamped(Wanted)
        guard New != Zoom else
        {
            return
        }
        let Point = Anchor ?? CGPoint(x: Viewport.width / 2, y: Viewport.height / 2)
        let Ratio = New / Zoom
        let Target = CGPoint(x: max((Tracker.Offset.x + Point.x) * Ratio - Point.x, 0),
                             y: max((Tracker.Offset.y + Point.y) * Ratio - Point.y, 0))
        Zoom = New
        // Set in the same update as the new size, so the picture does not jump between the two.
        Position.scrollTo(x: Target.x, y: Target.y)
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            ScrollView([.horizontal, .vertical])
            {
                Inner()
                    .frame(width: max(Viewport.width * Zoom, 1), height: max(Viewport.height * Zoom, 1))
            }
            .scrollPosition($Position)
            .scrollIndicators(.visible)
            .onScrollGeometryChange(for: CGPoint.self)
            {
                $0.contentOffset
            }
            action:
            {
                _, New in
                Tracker.Offset = New
            }
            .onGeometryChange(for: CGSize.self)
            {
                $0.size
            }
            action:
            {
                Viewport = $0
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged
                    {
                        Drag in
                        let Start = DragStart ?? Tracker.Offset
                        DragStart = Start
                        Position.scrollTo(x: max(Start.x - Drag.translation.width, 0), y: max(Start.y - Drag.translation.height, 0))
                    }
                    .onEnded
                    {
                        _ in
                        DragStart = nil
                    })
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged
                    {
                        Pinch in
                        let Start = PinchStart ?? Zoom
                        PinchStart = Start
                        SetZoom(Start * Pinch.magnification, Anchor: Pinch.startLocation)
                    }
                    .onEnded
                    {
                        _ in
                        PinchStart = nil
                    })
            #if os(macOS)
            .onContinuousHover
            {
                Phase in
                switch Phase
                {
                    case .active(let Place):
                        Tracker.Pointer = Place
                        WheelWatcher.IsInside = true
                    case .ended:
                        Tracker.Pointer = nil
                        WheelWatcher.IsInside = false
                }
            }
            #endif
            // The zoom controls are under the image, so they never hide the scroll bar.
            ZoomBar(Zoom: Binding(get: { Zoom }, set: { SetZoom($0, Anchor: nil) }))
                .padding(6)
        }
        #if os(macOS)
        .onAppear
        {
            WheelWatcher.Start
            {
                Change in
                SetZoom(Zoom * Change, Anchor: Tracker.Pointer)
            }
        }
        .onDisappear
        {
            WheelWatcher.Stop()
        }
        #endif
    }
}

/// What the zoom view remembers about the scroll position and pointer without being drawn again when they change.
@MainActor
final class ScrollTracker
{
    var Offset = CGPoint.zero
    var Pointer: CGPoint? = nil
}

/// The slider and buttons that set the zoom.
private struct ZoomBar: View
{
    @Binding var Zoom: Double

    /// The slider works on the logarithm of the zoom, so each step is the same proportion.
    private var LogZoom: Binding<Double>
    {
        Binding(get: { log2(Zoom) },
                set: { Zoom = ZoomableContainer<EmptyView>.Clamped(exp2($0)) })
    }

    var body: some View
    {
        HStack
        {
            Button("Zoom Out", systemImage: "minus.magnifyingglass")
            {
                Zoom = ZoomableContainer<EmptyView>.Clamped(Zoom / 1.25)
            }
            .keyboardShortcut("-", modifiers: .command)
            Slider(value: LogZoom, in: 0 ... log2(ZoomableContainer<EmptyView>.MaxZoom))
                .frame(maxWidth: 200)
            Button("Zoom In", systemImage: "plus.magnifyingglass")
            {
                Zoom = ZoomableContainer<EmptyView>.Clamped(Zoom * 1.25)
            }
            .keyboardShortcut("=", modifiers: .command)
            Text(Zoom, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
            Button("Fit", systemImage: "arrow.down.right.and.arrow.up.left")
            {
                Zoom = 1.0
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(Zoom == 1.0)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: .capsule)
    }
}

#if os(macOS)
/// Watches the scroll wheel while the pointer is over the view, and turns a mouse wheel into a zoom change. A trackpad's two-finger
/// scroll is not taken, so it still moves the image.
@MainActor
final class WheelZoomWatcher
{
    /// True while the pointer is over the view being watched.
    var IsInside = false
    private var Monitor: Any? = nil

    /// Starts watching.
    /// - Parameter OnChange: Called with the factor to multiply the zoom by.
    func Start(OnChange: @escaping (Double) -> Void)
    {
        Stop()
        Monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)
        {
            Event in
            MainActor.assumeIsolated
            {
                guard self.IsInside,
                      !Event.hasPreciseScrollingDeltas,
                      Event.scrollingDeltaY != 0 else
                {
                    return Event
                }
                OnChange(exp(Event.scrollingDeltaY * 0.05))
                return nil
            }
        }
    }

    /// Stops watching.
    func Stop()
    {
        if let Monitor
        {
            NSEvent.removeMonitor(Monitor)
        }
        Monitor = nil
    }
}
#endif
