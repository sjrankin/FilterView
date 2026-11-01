//
//  PanelDivider.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/31/26.
//

import SwiftUI

/// A thin divider the user can drag to resize the panel on its trailing or bottom side.
struct PanelDivider: View
{
    /// The panel's size along `Direction`: its width for `.horizontal`, its height for `.vertical`. Dragging toward the
    /// panel's far side (left or up) makes it larger.
    @Binding var Size: CGFloat
    /// Which way the panel is resized. `.horizontal` is a vertical divider with a panel on its right that changes width.
    /// `.vertical` is a horizontal divider with a panel below it that changes height.
    var Direction: Axis = .horizontal
    /// Smallest size the panel can be dragged to.
    var MinSize: CGFloat = 200
    /// Largest size the panel can be dragged to.
    var MaxSize: CGFloat = 600
    /// The panel's size when the current drag began. `nil` when not dragging.
    @State private var DragStartSize: CGFloat? = nil

    var body: some View
    {
        Rectangle()
            .fill(.separator)
            .frame(width: Direction == .horizontal ? 1 : nil, height: Direction == .vertical ? 1 : nil)
            // Wider grab area than the 1pt line.
            .padding(Direction == .horizontal ? .horizontal : .vertical, 4)
            .contentShape(.rect)
            #if os(macOS)
            // Resize cursor over the divider.
            .pointerStyle(Direction == .horizontal ? .columnResize : .rowResize)
            #endif
            .gesture(
                // Global space: the divider moves as the size changes, so a local space would shift under the drag and jitter.
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged
                    {
                        Value in
                        let Start = DragStartSize ?? Size
                        DragStartSize = Start
                        let Moved = Direction == .horizontal ? Value.translation.width : Value.translation.height
                        Size = min(max(Start - Moved, MinSize), MaxSize)
                    }
                    .onEnded
                    {
                        _ in
                        DragStartSize = nil
                    }
            )
    }
}

#Preview
{
    @Previewable @State var Size: CGFloat = 300
    PanelDivider(Size: $Size)
}
