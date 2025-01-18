FROM debian:bookworm AS builder

ENV PREFIX=/usr/local

# https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu
RUN apt-get update && \
    apt-get -y install \
      autoconf \
      automake \
      build-essential \
      cmake \
      git-core \
      libass-dev \
      libfreetype6-dev \
      libgnutls28-dev \
      libmp3lame-dev \
#      libsdl2-dev \
      libtool \
#      libva-dev \
#      libvdpau-dev \
      libvorbis-dev \
#      libxcb1-dev \
#      libxcb-shm0-dev \
#      libxcb-xfixes0-dev \
      meson \
      ninja-build \
      pkg-config \
      texinfo \
      wget \
      yasm \
      zlib1g-dev

RUN apt-get -y install \
      nasm \
      xxd \
      curl

# x264 http://www.videolan.org/developers/x264.html
# branch stable: https://code.videolan.org/videolan/x264/-/tree/stable?ref_type=heads
# https://code.videolan.org/videolan/x264/-/blob/stable/configure
RUN DIR=/tmp/x264 && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -fsSL 'https://code.videolan.org/videolan/x264/-/archive/31e19f92f00c7003fa115047ce50978bc98c3a0d/x264-31e19f92f00c7003fa115047ce50978bc98c3a0d.tar.gz' | tar -zx --strip-components=1 && \
    ./configure --extra-cflags="-O3 -march=native -pipe" --prefix="${PREFIX}" --enable-static --enable-pic --disable-cli && \
    make -j"$(nproc)" && \
    make install

# x265 http://x265.org/
# https://bitbucket.org/multicoreware/x265_git/downloads/
# https://github.com/videolan/x265/blob/master/source/CMakeLists.txt
RUN DIR=/tmp/x265 && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -fsSL 'https://bitbucket.org/multicoreware/x265_git/downloads/x265_4.1.tar.gz' | tar -zx --strip-components=1 && \
    cd ./build/linux && \
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DENABLE_SHARED=off -DNATIVE_BUILD=on -DENABLE_CLI=off -Wno-dev ../../source && \
    make -j"$(nproc)" && \
    make install

# libvpx https://www.webmproject.org/code/
# https://github.com/webmproject/libvpx/tags
RUN DIR=/tmp/vpx && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -fsSL 'https://github.com/webmproject/libvpx/archive/refs/tags/v1.15.0.tar.gz' | tar -zx --strip-components=1 && \
    ./configure --extra-cflags="-O3 -march=native -pipe" --extra-cxxflags='-O3 -march=native -pipe' --prefix="${PREFIX}" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm --disable-debug && \
    make -j"$(nproc)" && \
    make install

# fdk-aac https://github.com/mstorsjo/fdk-aac
# https://github.com/mstorsjo/fdk-aac/tags
RUN DIR=/tmp/fdk-aac && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -fsSL 'https://github.com/mstorsjo/fdk-aac/archive/refs/tags/v2.0.3.tar.gz' | tar -zx --strip-components=1 && \
    autoreconf -fiv && \
    ./configure CFLAGS="-O3 -march=native -pipe" CXXFLAGS='-O3 -march=native -pipe' --prefix="${PREFIX}" --disable-shared && \
    make -j"$(nproc)" && \
    make install

# libopus https://www.opus-codec.org/
# https://github.com/xiph/opus/releases
RUN DIR=/tmp/opus && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -fsSL 'https://github.com/xiph/opus/archive/refs/tags/v1.5.2.tar.gz' | tar -zx --strip-components=1 && \
    ./autogen.sh && \
    ./configure CFLAGS="-O3 -march=native -pipe" CXXFLAGS='-O3 -march=native -pipe' --prefix="${PREFIX}" --disable-shared && \
    make -j"$(nproc)" && \
    make install

# libaom https://aomedia.googlesource.com/aom
RUN DIR=/tmp/aom && \
    mkdir -p ${DIR} && cd ${DIR} && \
    git clone https://aomedia.googlesource.com/aom . && git checkout v3.11.0 && \
    mkdir aom_build && cd aom_build && \
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DENABLE_TESTS=OFF -DENABLE_NASM=ON -DENABLE_EXAMPLES=OFF .. && \
    make -j"$(nproc)" && \
    make install

# libsvtav1 https://gitlab.com/AOMediaCodec/SVT-AV1/-/releases
RUN DIR=/tmp/svtav1 && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -fsSL 'https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v2.3.0/SVT-AV1-v2.3.0.tar.gz' | tar -zx --strip-components=1 && \
    cd Build && \
    cmake .. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_APPS=OFF -DNATIVE=ON && \
    make -j $(nproc) && \
    make install

# libdav1d https://code.videolan.org/videolan/dav1d/-/releases
RUN DIR=/tmp/dav1d && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -fsSL 'https://code.videolan.org/videolan/dav1d/-/archive/1.5.0/dav1d-1.5.0.tar.gz' | tar -zx --strip-components=1 && \
    mkdir build && cd build && \
    meson setup -Denable_tools=false -Denable_tests=false --default-library=static .. --prefix "${PREFIX}" --libdir="${PREFIX}/lib" && \
    ninja && \
    ninja install

# libvmaf https://github.com/Netflix/vmaf/releases
RUN DIR=/tmp/vmaf && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -fsSL 'https://github.com/Netflix/vmaf/archive/refs/tags/v3.0.0.tar.gz' | tar -zx --strip-components=1 && \
    mkdir -p libvmaf/vmaf_build && cd libvmaf/vmaf_build && \
    meson setup -Denable_tests=false -Denable_docs=false --buildtype=release --default-library=static .. --prefix "${PREFIX}" --libdir="${PREFIX}/lib" && \
    ninja && \
    ninja install

# ffmpeg
# https://github.com/FFmpeg/FFmpeg/blob/master/configure
# https://github.com/FFmpeg/FFmpeg/tags
RUN DIR=/tmp/ffmpeg_sources && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -fsSL 'https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n7.1.tar.gz' | tar -zx --strip-components=1 && \
    # https://askubuntu.com/questions/1252997/unable-to-compile-ffmpeg-on-ubuntu-20-04
    apt-get install -y libunistring-dev libssl-dev && \
    ./configure \
      --prefix=${PREFIX} \
      --pkg-config-flags="--static" \
      --extra-cflags="-I${PREFIX}/include -march=native" \
      --extra-ldflags="-L${PREFIX}/lib" \
      --extra-libs="-lpthread -lm" \
      --enable-optimizations \
      --enable-lto \
      --enable-static \
      --disable-shared \
      --enable-gpl \
      --enable-version3 \
      --enable-nonfree \
      --enable-openssl \
      --enable-libaom \
      --enable-libass \
      --enable-libfdk-aac \
      --enable-libfreetype \
      --enable-libmp3lame \
      --enable-libopus \
      --enable-libsvtav1 \
      --enable-libdav1d \
      --enable-libvorbis \
      --enable-libvpx \
      --enable-libx264 \
      --enable-libx265 \
      # disable Video Acceleration API (mainly Unix/Intel) code [autodetect]
      --disable-vaapi \
      # disable Nvidia Video Decode and Presentation API for Unix code [autodetect]
      --disable-vdpau \
      # disable ffplay build
      --disable-ffplay \
      # disable debugging symbols
      --disable-debug && \
    make -j"$(nproc)" && \
    make install



FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get -y install \
      libmp3lame0 \
      libvorbis0a \
      libvorbisenc2 \
      libssl3 \
      libass9 \
      libfreetype6 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin /usr/local/bin
WORKDIR /usr/local/bin

CMD        ["--help"]
ENTRYPOINT ["ffmpeg"]
