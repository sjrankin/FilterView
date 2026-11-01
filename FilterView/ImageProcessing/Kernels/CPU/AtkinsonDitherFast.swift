//
//  AtkinsonDitherFast.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 10/31/26.
//

import Foundation
import CoreGraphics
import Synchronization

/// A faster black and white Atkinson error-diffusion dither, meant for live video. It sits beside `AtkinsonDither`, which is
/// unchanged. The result looks the same as `AtkinsonDither` but is not pixel-for-pixel identical, because this one uses
/// whole-number math and error diffusion magnifies tiny differences in rounding. It is exactly the same however many
/// workers run it.
///
/// It is faster for two reasons:
/// - Whole-number math with a fixed-point error. Each pixel depends on the one before it, so the loop is a chain of dependent
/// operations, and whole-number operations finish sooner than floating-point ones. Only a few rows of error are kept, in raw
/// buffers, so the inner loop does no array bounds checks and touches little memory.
/// - Several rows are dithered at the same time on separate cores, as a staggered pipeline. A pixel needs only the pixels
/// up to two to the right in the row above, so a row can start as soon as the row above is a short way ahead of it. The error
/// is handed from row to row exactly as in a single pass, so there are no seams or bands in the result.
/// - Important: This is `nonisolated` and its work is `@concurrent`. The project's default is to run code on the main actor, which
/// would put every worker on the main thread, where they take turns instead of running together (and block the interface).
nonisolated struct AtkinsonDitherFast: ImageFilter
{
    static let FilterName = "Atkinson Dither Fast"

    /// Option key for the black/white threshold, a `Float` in 0.0 to 1.0. Default is 0.5. Same key as `AtkinsonDither`.
    static let ThresholdKey = "Threshold"

    /// Option key for the number of rows dithered at once, an `Int` (or a string holding one). It does not change the result,
    /// only the speed. 1 runs on a single core. Default is `DefaultWorkers`.
    static let WorkersKey = "Workers"

    /// Workers used when none are given: one per core, up to 8 (more gain little).
    static var DefaultWorkers: Int
    {
        max(1, min(ProcessInfo.processInfo.activeProcessorCount, 8))
    }

    /// Fewest rows per worker. A worker is only useful once the rows above it have started, so very short images get fewer.
    static let MinimumRowsPerWorker = 8

    /// Pixels a row does between checks on the row above (and between reports of its own progress).
    private static let ChunkSize = 32

    /// Value of a fully white pixel in the fixed-point math (255 shifted left 8 bits).
    private static let White: Int32 = 255 << 8

    var FilterType: ImageFilterTypes
    {
        .CPU
    }

    /// Dither the passed image to black and white using Atkinson error diffusion.
    /// - Parameter Input: The image to process.
    /// - Parameter Options: Optional dictionary. Recognized keys are `ThresholdKey` and `WorkersKey`.
    /// - Returns: An 8-bit grayscale image containing only black and white pixels, the same size as `Input`.
    /// - Throws: `FilterException` if the image cannot be read or written, `CancellationError` if cancelled.
    @concurrent func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()

        let Width = Input.width
        let Height = Input.height
        guard Width > 0, Height > 0 else
        {
            throw FilterException(Message: "Empty image passed to AtkinsonDitherFast.")
        }
        let Threshold = min(max((Options?[AtkinsonDitherFast.ThresholdKey] as? Float) ?? 0.5, 0.0), 1.0)
        var Workers = AtkinsonDitherFast.DefaultWorkers
        if let Given = Options?[AtkinsonDitherFast.WorkersKey]
        {
            Workers = (Given as? Int) ?? Int(Given as? String ?? "") ?? Workers
        }
        Workers = max(1, min(Workers, Height / AtkinsonDitherFast.MinimumRowsPerWorker))

        // The buffers are shared by the worker tasks, so they are raw memory rather than arrays.
        let Count = Width * Height
        let GrayBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Count)
        let OutBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Count)
        GrayBuffer.initialize(repeating: 0, count: Count)
        OutBuffer.initialize(repeating: 0, count: Count)
        // Error rows. A row needs its own, the next, and the one after, and a worker begins a new row only when it has finished
        // one `Workers` rows earlier, so `Workers + 2` rows reused in turn are enough. Each has two spare entries on both sides
        // so the inner loop needs no edge checks. Pixel X of a row is at index X + 2.
        let Ring = Workers + 2
        let Stride = Width + 4
        let Errors = UnsafeMutablePointer<Int32>.allocate(capacity: Stride * Ring)
        Errors.initialize(repeating: 0, count: Stride * Ring)
        // How many pixels of each row are finished. A row waits on the row above's count.
        let Progress = UnsafeMutablePointer<Atomic<Int>>.allocate(capacity: Height)
        for Row in 0 ..< Height
        {
            (Progress + Row).initialize(to: Atomic<Int>(0))
        }
        defer
        {
            GrayBuffer.deallocate()
            OutBuffer.deallocate()
            Errors.deallocate()
            Progress.deinitialize(count: Height)
            Progress.deallocate()
        }

        // Let CoreGraphics do the color to gray conversion.
        guard let Context = CGContext(data: GrayBuffer,
                                      width: Width,
                                      height: Height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: Width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else
        {
            throw FilterException(Message: "Could not create gray context in AtkinsonDitherFast.")
        }
        Context.draw(Input, in: CGRect(x: 0, y: 0, width: Width, height: Height))

        let Shared = SharedState(Gray: UnsafePointer(GrayBuffer),
                                 Out: OutBuffer,
                                 Errors: Errors,
                                 Progress: Progress,
                                 Width: Width,
                                 Height: Height,
                                 Ring: Ring,
                                 Cutoff: Int32(Threshold * Float(AtkinsonDitherFast.White)))
        // Worker N does rows N, N + Workers, N + 2 * Workers, and so on.
        await withTaskGroup(of: Void.self)
        {
            Group in
            for Worker in 0 ..< Workers
            {
                Group.addTask
                {
                    await AtkinsonDitherFast.DitherRows(Shared, First: Worker, Step: Workers)
                }
            }
        }
        try Task.checkCancellation()

        guard let Provider = CGDataProvider(data: Data(bytes: OutBuffer, count: Count) as CFData),
              let Output = CGImage(width: Width,
                                   height: Height,
                                   bitsPerComponent: 8,
                                   bitsPerPixel: 8,
                                   bytesPerRow: Width,
                                   space: CGColorSpaceCreateDeviceGray(),
                                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                   provider: Provider,
                                   decode: nil,
                                   shouldInterpolate: false,
                                   intent: .defaultIntent) else
        {
            throw FilterException(Message: "Error from AtkinsonDitherFast.")
        }
        return Output
    }

    /// The buffers and settings shared by the worker tasks. The tasks never write the same memory at the same time: a row
    /// only reads error that the row above has finished and reported through `Progress`, and the reports use acquire and release
    /// ordering so the error is visible by then.
    private struct SharedState: @unchecked Sendable
    {
        let Gray: UnsafePointer<UInt8>
        let Out: UnsafeMutablePointer<UInt8>
        let Errors: UnsafeMutablePointer<Int32>
        let Progress: UnsafeMutablePointer<Atomic<Int>>
        let Width: Int
        let Height: Int
        let Ring: Int
        /// Pixels at or above this value (0 to 65280) become white.
        let Cutoff: Int32
    }

    /// Dithers every `Step`th row starting at `First`. Runs off the main thread, in a worker task.
    /// - Parameter Shared: The shared buffers and settings.
    /// - Parameter First: The first row for this worker.
    /// - Parameter Step: Rows between this worker's rows, which is the number of workers.
    /// - Note: Returns early, without finishing its rows, if the task is cancelled. Every worker is cancelled together, so
    /// none is left waiting on a row that will not be finished.
    @concurrent private static func DitherRows(_ Shared: SharedState, First: Int, Step: Int) async
    {
        let Width = Shared.Width
        let Stride = Width + 4
        var Y = First
        while Y < Shared.Height
        {
            let Current = Shared.Errors + (Y % Shared.Ring) * Stride
            let Next = Shared.Errors + ((Y + 1) % Shared.Ring) * Stride
            let NextAfter = Shared.Errors + ((Y + 2) % Shared.Ring) * Stride
            let Source = Shared.Gray + Y * Width
            let Target = Shared.Out + Y * Width
            // Error waiting for this pixel and the next, kept in variables instead of memory.
            var ForThis: Int32 = 0
            var ForNext: Int32 = 0
            // The shares given out for the last two pixels, which the next row needs.
            var ShareBefore: Int32 = 0
            var ShareBeforeThat: Int32 = 0
            var Start = 0
            while Start < Width
            {
                let End = min(Start + ChunkSize, Width)
                if Y > 0
                {
                    // The row above must have finished the pixels this chunk takes error from, which reach four past the end.
                    let Needed = min(Width, End + 4)
                    while Shared.Progress[Y - 1].load(ordering: .acquiring) < Needed
                    {
                        if Task.isCancelled
                        {
                            return
                        }
                        await Task.yield()
                    }
                }
                if Start == 0
                {
                    ForThis = Current[2]
                    ForNext = Current[3]
                }
                for X in Start ..< End
                {
                    let Old = (Int32(Source[X]) << 8) + ForThis
                    let IsWhite = Old >= Shared.Cutoff
                    Target[X] = IsWhite ? 255 : 0
                    // Atkinson gives 1/8 of the error to six neighbors, which passes on 3/4 of it in all.
                    let Share = (Old - (IsWhite ? White : 0)) >> 3
                    ForThis = ForNext + Share
                    ForNext = Current[X + 4] + Share
                    // The pixel to the lower left is now complete: it gets a share from the pixels at its upper left, above,
                    // and upper right.
                    Next[X + 1] += ShareBeforeThat + ShareBefore + Share
                    NextAfter[X + 2] += Share
                    ShareBeforeThat = ShareBefore
                    ShareBefore = Share
                }
                if End == Width
                {
                    // The last pixel of the next row has no upper right neighbor.
                    Next[Width + 1] += ShareBeforeThat + ShareBefore
                }
                // Report progress only after the error for these pixels has been written.
                Shared.Progress[Y].store(End, ordering: .releasing)
                Start = End
            }
            // This row's error is used up. Clear it so it can serve as a later row.
            Current.update(repeating: 0, count: Stride)
            Y += Step
        }
    }
}
