FROM ubuntu:noble as builder

ENV PREFIX=/usr/local \
    FFMPEG_VERSION=7.0.1 \
    X264_VERSION=4613ac3c15fd75cebc4b9f65b7fb95e70a3acce1 \
    X265_VERSION=3.6 \
    FDKAAC_VERSION=2.0.3 \
    VPX_VERSION=1.14.1 \
    OPUS_VERSION=1.5.2 \
    AOM_VERSION=3.9.1 \
    SVTAV1_VERSION=2.1.2 \
    DAV1D_VERSION=1.4.3 \
    VMAF_VERSION=3.0.0

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
      curl

# x264 http://www.videolan.org/developers/x264.html
# https://code.videolan.org/videolan/x264/-/blob/master/configure
RUN DIR=/tmp/x264 && \
    mkdir -p ${DIR} && cd ${DIR} && \
    git clone https://code.videolan.org/videolan/x264.git . && git checkout ${X264_VERSION} && \
    ./configure --extra-cflags="-O3 -march=native -pipe" --prefix="${PREFIX}" --enable-static --enable-pic --disable-cli && \
    make -j"$(nproc)" && \
    make install

# x265 http://x265.org/
# https://github.com/videolan/x265/blob/master/source/CMakeLists.txt
RUN DIR=/tmp/x265 && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -fsSL https://bitbucket.org/multicoreware/x265_git/downloads/x265_${X265_VERSION}.tar.gz | tar -zx --strip-components=1 && \
    cd ./build/linux && \
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DENABLE_SHARED=off -DNATIVE_BUILD=on -DENABLE_CLI=off -Wno-dev ../../source && \
    make -j"$(nproc)" && \
    make install

# libvpx https://www.webmproject.org/code/
RUN DIR=/tmp/vpx && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -sL https://github.com/webmproject/libvpx/archive/refs/tags/v${VPX_VERSION}.tar.gz | tar -zx --strip-components=1 && \
    ./configure --extra-cflags="-O3 -march=native -pipe" --extra-cxxflags='-O3 -march=native -pipe' --prefix="${PREFIX}" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm --disable-debug && \
    make -j"$(nproc)" && \
    make install

# fdk-aac https://github.com/mstorsjo/fdk-aac
RUN DIR=/tmp/fdk-aac && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -sL https://github.com/mstorsjo/fdk-aac/archive/refs/tags/v${FDKAAC_VERSION}.tar.gz | tar -zx --strip-components=1 && \
    autoreconf -fiv && \
    ./configure CFLAGS="-O3 -march=native -pipe" CXXFLAGS='-O3 -march=native -pipe' --prefix="${PREFIX}" --disable-shared && \
    make -j"$(nproc)" && \
    make install

# libopus https://www.opus-codec.org/
RUN DIR=/tmp/opus && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -sL https://github.com/xiph/opus/archive/refs/tags/v${OPUS_VERSION}.tar.gz | tar -zx --strip-components=1 && \
    ./autogen.sh && \
    ./configure CFLAGS="-O3 -march=native -pipe" CXXFLAGS='-O3 -march=native -pipe' --prefix="${PREFIX}" --disable-shared && \
    make -j"$(nproc)" && \
    make install

# libaom https://aomedia.googlesource.com/aom
RUN DIR=/tmp/aom && \
    mkdir -p ${DIR} && cd ${DIR} && \
    git clone https://aomedia.googlesource.com/aom . && git checkout v${AOM_VERSION} && \
    mkdir aom_build && cd aom_build && \
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DENABLE_TESTS=OFF -DENABLE_NASM=on .. && \
    make -j"$(nproc)" && \
    make install

# libsvtav1 https://gitlab.com/AOMediaCodec/SVT-AV1/-/tags
RUN DIR=/tmp/svtav1 && \
    mkdir -p ${DIR} && cd ${DIR} && \
    git clone https://gitlab.com/AOMediaCodec/SVT-AV1.git . && git checkout v${SVTAV1_VERSION} && \
    mkdir svtav1_build && cd svtav1_build && \
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DCMAKE_BUILD_TYPE=Release -DBUILD_DEC=OFF -DBUILD_SHARED_LIBS=OFF .. && \
    make -j"$(nproc)" && \
    make install

# libdav1d https://code.videolan.org/videolan/dav1d/-/tags
RUN DIR=/tmp/dav1d && \
    mkdir -p ${DIR} && cd ${DIR} && \
    git clone https://code.videolan.org/videolan/dav1d.git . && git checkout ${DAV1D_VERSION} && \
    mkdir dav1d_build && cd dav1d_build && \
    meson setup -Denable_tools=false -Denable_tests=false --default-library=static .. --prefix "${PREFIX}" --libdir="${PREFIX}/lib" && \
    ninja && \
    ninja install

# libvmaf https://github.com/Netflix/vmaf/releases
RUN DIR=/tmp/vmaf && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -sL https://github.com/Netflix/vmaf/archive/refs/tags/v${VMAF_VERSION}.tar.gz | tar -zx --strip-components=1 && \
    mkdir -p libvmaf/vmaf_build && cd libvmaf/vmaf_build && \
    meson setup -Denable_tests=false -Denable_docs=false --buildtype=release --default-library=static .. --prefix "${PREFIX}" --libdir="${PREFIX}/lib" && \
    ninja && \
    ninja install

# ffmpeg
# https://github.com/FFmpeg/FFmpeg/blob/master/configure
RUN DIR=/tmp/ffmpeg_sources && \
    mkdir -p ${DIR} && cd ${DIR} && \
    curl -fsSL https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n${FFMPEG_VERSION}.tar.gz | tar -zx --strip-components=1 && \
    # https://askubuntu.com/questions/1252997/unable-to-compile-ffmpeg-on-ubuntu-20-04
    apt-get install -y libunistring-dev && \
    ./configure \
      --prefix=${PREFIX} \
      --pkg-config-flags=--static \
      --extra-cflags="-I${PREFIX}/include" \
      --extra-ldflags="-L${PREFIX}/lib" \
      --extra-libs="-lpthread -lm" \
      --extra-cflags="-march=native -pipe" \
      --optflags="-O3" \
      --enable-gpl \
      --enable-gnutls \
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
      --enable-nonfree \
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



FROM ubuntu:noble

RUN apt-get update && \
    apt-get -y install \
      libmp3lame0 \
      libvorbis0a \
      libvorbisenc2 \
      libass9 \
      libfreetype6 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
      
COPY --from=builder /usr/local/ /usr/local
WORKDIR /usr/local/bin

CMD        ["--help"]
ENTRYPOINT ["ffmpeg"]
