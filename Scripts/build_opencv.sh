#!/bin/zsh
# Builds Frameworks/opencv2.xcframework (macOS, arm64) from the OpenCV source. Needs cmake (brew install cmake) and Xcode.
# Usage: Scripts/build_opencv.sh [OpenCV version tag, default 4.14.0]
#
# - Modules dnn, videoio and video are left out: dnn is large, and videoio fails against Homebrew's newer FFmpeg headers.
# - The OpenCV script needs a named branch, so the shallow clone of the tag gets one.
# - CMake 4.x with the Xcode generator cannot find the compiler under Xcode 27, so a cmake wrapper passes the compilers explicitly.
set -e
Version=${1:-4.14.0}
Root=$(cd "$(dirname "$0")/.." && pwd)
Work=${OPENCV_WORK:-$HOME/Developer/OpenCVBuild}
mkdir -p "$Work/bin"
if [[ ! -d "$Work/opencv" ]]
then
    git clone --depth 1 --branch "$Version" https://github.com/opencv/opencv.git "$Work/opencv"
    git -C "$Work/opencv" checkout -q -b "build-$Version"
fi
cat > "$Work/bin/cmake" <<'WRAP'
#!/bin/zsh
if [[ "$*" == *"-GXcode"* ]]
then
    exec /opt/homebrew/bin/cmake "$@" "-DCMAKE_C_COMPILER=$(xcrun -find clang)" "-DCMAKE_CXX_COMPILER=$(xcrun -find clang++)"
fi
exec /opt/homebrew/bin/cmake "$@"
WRAP
chmod +x "$Work/bin/cmake"
rm -rf "$Work/out"
(cd "$Work" && PATH="$Work/bin:$PATH" python3 -W ignore opencv/platforms/apple/build_xcframework.py -o out \
    --macos_archs arm64 --build_only_specified_archs --without dnn --without videoio --without video --macosx_deployment_target 14.0)
rm -rf "$Root/Frameworks/opencv2.xcframework"
mkdir -p "$Root/Frameworks"
cp -R "$Work/out/opencv2.xcframework" "$Root/Frameworks/"
echo "Installed $Root/Frameworks/opencv2.xcframework"
