# FilterView
Stuart Rankin\
October 2026

# Summary
This is a program that applies various graphical filters to user-selected images, which may be saved at the user's discretion. App allows for input from an existing image file, a photo taken by the device's camera, and a video stream from the devices camera. Filtered video streams may be saved.

## Filters
For the purposes of this app, a filter is anything that modifies an image.

## Input
There are two primary types of input for FilterView:
1. Still images (drag and drop, load an image file)
2. Video stream

## Pipelines
A pipeline is a sequence of filters. One filter stage is fed into the next. Filters can branch and rejoin the main pipeline at other (but not retrograde) stages.

# Filters
There are four major types of filters, grouped by implementation.

## CPU
CPU filters run on the CPU and are not GPU-accelerated. The canonical filter for this is the Atkinson Dithering filter. Initially, it ran significantly slower than GPU filters. With optimization, it is now on a par with the GPU. (Atkinson runs on the CPU because of error diffision is difficult on GPUs.)
## CoreImage
iOS/macOS have many CoreImage filters. Many were incorporated into FilterView.
## OpenCV
OpenCV is an open source computer vision framework that has filtering capabilities. OpenCV required building it for embedding rather than relying on the libraries being present on any given system. OpenCV filtering is available only on the macOS version of FilterView.

### Building the OpenCV framework
FilterView links OpenCV 4.14.0 statically from `Frameworks/opencv2.xcframework`. The framework is about 53 MB, so it is not stored in the repository (it is listed in `.gitignore`). After cloning, build it once before building the macOS app:

1. Install the prerequisites: Xcode, Homebrew's CMake (`brew install cmake`), and Python 3.
2. Run the build script from the repository root:

```
Scripts/build_opencv.sh
```

The script clones the OpenCV source into `~/Developer/OpenCVBuild` (set `OPENCV_WORK` to use another folder), builds a macOS arm64 static framework, and copies it to `Frameworks/opencv2.xcframework`. Pass a version tag to build a different release, for example `Scripts/build_opencv.sh 4.14.0`. The build takes several minutes.

Notes:
- The `dnn`, `videoio` and `video` modules are left out. FilterView does not use them, and `videoio` does not compile against current Homebrew FFmpeg headers.
- The framework is built for Apple silicon (arm64) with a macOS 14.0 deployment target. An Intel Mac build would need `--macos_archs x86_64` added to the script.
- The framework is linked into the macOS target only. The iOS build does not need it, and the OpenCV group is hidden from the filter tree on iOS.
- Without the framework, the macOS target fails to build with a missing `opencv2` module. The iOS target is unaffected.
- OpenCV is licensed under the Apache License 2.0, the same license as FilterView. See [opencv.org/license](https://opencv.org/license/).
## Metal
Metal is Apple's name for its GPU shader language. Several Metal filters were incorporated, including some I directly Claude to write, MPS filters, and filters I wrote myself.

# User Interface
The window that opens with the app is the main window and consists of a large view for the current image, a tree of filters, associated options, and controls for selecting input and opening and controlling the pipeline window. The user can access settings by tapping the gear button in the upper right.

Example of the main user interface.\
<img src="Images/MainUI.png" alt="Main user interface." width="800">
The large image will change when the user changes a filter. The image can be saved at anytime but the changes are transitory in the sense selecting another filter will stop using the previous filter. The original image is not changed (unless the user overwrites it intentionally). The smaller duplicate on the right side is unchanging so the user knows the extent of the filter changes.

The sample image (and used as a source for many examples) is shown below:\
<img src="Images/Hana.jpg" alt="Main user interface." width="400">

Filters are selected by opening the filter tree in the upper right and tapping on a given filter. Options, if any, for the filter are at the bottom, under the base image. Options can be reset, and are saved for future instantiations.

## Filtering parts of an image
The three split buttons under the image (left and right, top and bottom, four quadrants) divide the image into regions that each get their own filter. Tap a region on the image to edit it, then choose a filter and set its options; the region keeps that filter when you tap another one. A new split starts with the filter you had chosen in the first region and no filter in the others, which show the original. Tap the active split button again to put the image back together.

Each region's filter runs on the whole image and only the part inside the region is kept, so filters that look at neighboring pixels (blurs, edge detection) are not cut off at the dividing line. Saving, live video and batch mode all use the regions.

In the Pipeline window, **Partial Splitter** adds a splitter after the last stage: a split stage, one line of stages for each region hanging under it, and a join stage that puts the final image of each line in its region. Give each line's first stage a filter with Use Selected Filter and add more stages to a line with Insert Filter After; each line's last stage is what the join uses. The join is the end of the main line, so the pipeline continues from it. The stages of a splitter can be skipped but not deleted one at a time; **Remove Partial Splitter** takes the whole splitter out. Splitters are saved with the pipeline.

## Batch mode
Choose several images with Load (or drag several onto the image area on macOS) to work on them as a batch. The images appear in a grid where the single image was shown, and choosing a filter updates every image. Tap an image to make it the current one; its name and size are shown in the filter panel and the Pipeline window starts from it.

- **Save All** runs the selected filter on every image and saves each result in the folder it was read from, with `_fv` added to the name (`beach.jpg` becomes `beach_fv.jpg`). A file whose format cannot be written is saved as PNG.
- **Pipelines:** while the Pipeline window is open, its **Save All Images** button runs every image through the pipeline, updating the grid as each one finishes, and saves them the same way.
- **Folders the app cannot write to:** FilterView is sandboxed, so it can only write where you have allowed it. If a saved copy cannot be written beside its original, the app asks what to do: choose one folder for every image that cannot be saved in place, choose a place for just that image, or skip it. A message at the end says how many were saved, skipped, or failed.
- **Previews:** the grid filters reduced copies (1024 pixels on the longest side) to stay fast and light on memory. Saving reloads each file and filters it at full size, up to 4096 pixels on the longest side, so filter options measured in pixels can look a little different in the grid than in the saved file.
- Loading a single image, taking a photo, or pressing Reset Image leaves batch mode.

## Pipelines
Pipelines are the most important part of FilterView. They allow users to create combined filters, save them, and use them later. Pipelines can be embedded in other pipelines, allowing for functional composition. Pipelines can be edited in place and stages added or removed.

The pipeline user interface with no pipeline stages yet added:\
<img src="Images/PipelineUI.png" alt="Empty pipeline user interface." width="800">

<img src="Images/FilterView+BoardTestG.gif" alt="Inverse color." width="400">

<img src="Images/FilterView+BoardTestG_CannyEdgeDetector.gif" alt="Canny edge detector running in a video stream." width="400">

# Copyright and License

Copyright 2026 Stuart Rankin

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://apache.org

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
