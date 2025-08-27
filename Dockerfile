FROM --platform=linux/arm64 debian:bullseye
MAINTAINER Andrey Volk <andrey@signalwire.com>

# Set architecture-specific variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TARGETARCH=arm64

RUN apt-get update && apt-get -yq install git

# Clone repositories
RUN git clone https://github.com/signalwire/freeswitch /usr/src/freeswitch
RUN git clone https://github.com/signalwire/libks /usr/src/libs/libks
RUN git clone https://github.com/freeswitch/sofia-sip /usr/src/libs/sofia-sip
RUN git clone https://github.com/freeswitch/spandsp /usr/src/libs/spandsp
RUN git clone https://github.com/signalwire/signalwire-c /usr/src/libs/signalwire-c

# Install essential debugging and networking tools
RUN apt-get -yq install lsof net-tools iputils-ping vim curl dnsutils

# Install build dependencies
RUN apt-get -yq install \
# build tools
    build-essential cmake automake autoconf 'libtool-bin|libtool' pkg-config \
# general dependencies
    libssl-dev zlib1g-dev libdb-dev unixodbc-dev libncurses5-dev libexpat1-dev libgdbm-dev bison erlang-dev libtpl-dev libtiff5-dev uuid-dev \
# core dependencies
    libpcre2-dev libedit-dev libsqlite3-dev libcurl4-openssl-dev \
# core codecs
    libogg-dev libspeex-dev libspeexdsp-dev \
# mod_enum
    libldns-dev \
# mod_python3
    python3-dev \
# mod_av
    libavformat-dev libswscale-dev \
# mod_lua
    liblua5.2-dev \
# mod_opus
    libopus-dev \
# mod_pgsql
    libpq-dev \
# mod_sndfile
    libsndfile1-dev libflac-dev libogg-dev libvorbis-dev \
# mod_shout
    libshout3-dev libmpg123-dev libmp3lame-dev

# Note: Removed nasm (x86-only assembler) and libavresample-dev (deprecated)
# For ARM64, we don't need nasm and libavresample is replaced by libswresample

# Build and install libks with ARM64 optimizations
RUN cd /usr/src/libs/libks && \
    cmake . -DCMAKE_INSTALL_PREFIX=/usr \
           -DWITH_LIBBACKTRACE=1 \
           -DCMAKE_BUILD_TYPE=Release \
           -DCMAKE_C_FLAGS="-O2 -march=armv8-a" && \
    make install

# Build and install sofia-sip
RUN cd /usr/src/libs/sofia-sip && \
    ./bootstrap.sh && \
    ./configure CFLAGS="-g -ggdb -O2 -march=armv8-a" \
                --with-pic \
                --with-glib=no \
                --without-doxygen \
                --disable-stun \
                --prefix=/usr \
                --build=aarch64-linux-gnu && \
    make -j$(nproc --all) && \
    make install

# Build and install spandsp
RUN cd /usr/src/libs/spandsp && \
    ./bootstrap.sh && \
    ./configure CFLAGS="-g -ggdb -O2 -march=armv8-a" \
                --with-pic \
                --prefix=/usr \
                --build=aarch64-linux-gnu && \
    make -j$(nproc --all) && \
    make install

# Build and install signalwire-c
RUN cd /usr/src/libs/signalwire-c && \
    PKG_CONFIG_PATH=/usr/lib/pkgconfig \
    cmake . -DCMAKE_INSTALL_PREFIX=/usr \
           -DCMAKE_BUILD_TYPE=Release \
           -DCMAKE_C_FLAGS="-O2 -march=armv8-a" && \
    make install

# Enable modules
RUN sed -i 's|#formats/mod_shout|formats/mod_shout|' /usr/src/freeswitch/build/modules.conf.in

# Build FreeSWITCH
RUN cd /usr/src/freeswitch && ./bootstrap.sh -j

RUN cd /usr/src/freeswitch && \
    ./configure --build=aarch64-linux-gnu \
                --host=aarch64-linux-gnu \
                --enable-portable-binary \
                --disable-dependency-tracking \
                CFLAGS="-O2 -march=armv8-a -mtune=cortex-a72"

RUN cd /usr/src/freeswitch && \
    make -j$(nproc) && \
    make install

# Cleanup the image
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Uncomment to cleanup even more (saves significant space)
#RUN rm -rf /usr/src/*

# Set up runtime environment
EXPOSE 5060/tcp 5060/udp 5080/tcp 5080/udp
EXPOSE 8021/tcp
EXPOSE 16384-16404/udp

# Create freeswitch user and set permissions
RUN useradd --system --user-group --shell /bin/false --home-dir /usr/local/freeswitch --create-home freeswitch && \
    chown -R freeswitch:freeswitch /usr/local/freeswitch && \
    chmod -R 755 /usr/local/freeswitch

# Set up default configuration if not mounted
RUN mkdir -p /usr/local/freeswitch/conf /usr/local/freeswitch/log /usr/local/freeswitch/db /usr/local/freeswitch/recordings

# Set environment variables
ENV FREESWITCH_PASSWORD=ClueCon

USER freeswitch
WORKDIR /usr/local/freeswitch

# Start FreeSWITCH in foreground mode
CMD ["/usr/local/freeswitch/bin/freeswitch", "-nf"]