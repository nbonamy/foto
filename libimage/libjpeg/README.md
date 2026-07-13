# Vendored libjpeg-turbo

This directory contains the headers and a universal macOS static archive from
[libjpeg-turbo 3.1.4.1](https://github.com/libjpeg-turbo/libjpeg-turbo/releases/tag/3.1.4.1).
The archive preserves both the libjpeg v6.2 ABI and the TurboJPEG API.

The `arm64` slice is built with NEON SIMD enabled. The `x86_64` slice is built
without NASM SIMD because those Mach-O objects do not contain an Apple platform
load command and trigger linker warnings in current Xcode versions. Both slices
target macOS 12.

Build each architecture separately with CMake and Ninja:

```sh
cmake -S libjpeg-turbo -B build-arm64 -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
  -DENABLE_SHARED=FALSE \
  -DENABLE_STATIC=TRUE \
  -DWITH_TURBOJPEG=TRUE \
  -DWITH_SIMD=TRUE

cmake -S libjpeg-turbo -B build-x86_64 -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
  -DENABLE_SHARED=FALSE \
  -DENABLE_STATIC=TRUE \
  -DWITH_TURBOJPEG=TRUE \
  -DWITH_SIMD=FALSE

cmake --build build-arm64 --parallel
cmake --build build-x86_64 --parallel
ctest --test-dir build-arm64 --output-on-failure
ctest --test-dir build-x86_64 --output-on-failure
lipo -create build-arm64/libturbojpeg.a build-x86_64/libturbojpeg.a \
  -output libjpeg.a
```

Refresh the public headers from the same source release and `jconfig.h` /
`jversion.h` from the `arm64` build directory.
