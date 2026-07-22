# i386 image: Gildor's Linux umodel is a 32-bit x86 ELF. Under colima it runs via
# qemu-i386 user emulation (binfmt). An i386 userland gives it matching 32-bit libs.
FROM --platform=linux/386 debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        libsdl2-2.0-0 \
        libgl1 \
        libglx-mesa0 \
        libgl1-mesa-dri \
        libglu1-mesa \
        xvfb \
        xauth \
        x11-utils \
        zlib1g \
        libpng16-16 \
        file \
    && rm -rf /var/lib/apt/lists/*

# umodel is linked against the long-removed libpng12 (i386). Provide the archived
# library directly (extracted from libpng12-0_1.2.54 i386 .deb).
COPY libpng12.so.0 /usr/lib/i386-linux-gnu/libpng12.so.0
RUN ldconfig

ENV LIBGL_ALWAYS_SOFTWARE=1
WORKDIR /work
