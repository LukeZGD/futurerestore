#!/bin/bash
# For compiling libimobiledevice, libirecovery, and idevicerestore for Linux/Windows

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig
export JNUM="-j$(nproc)"

rm -rf tmp
mkdir bin tmp 2>/dev/null
cd tmp

set -e

if [[ $OSTYPE == "linux"* ]]; then
    platform="linux"
    echo "* Platform: Linux"
    if [[ ! -f "/etc/lsb-release" && ! -f "/etc/debian_version" ]]; then
        echo "[Error] Ubuntu/Debian only"
        exit 1
    fi

    # based on Cryptiiiic's futurerestore static linux compile script
    export DIR=$(pwd)
    export FR_BASE="$DIR"
    export CC_ARGS="CC=/usr/bin/gcc CXX=/usr/bin/g++ LD=/usr/bin/ld RANLIB=/usr/bin/ranlib AR=/usr/bin/ar"
    export ALT_CC_ARGS="CC=/usr/bin/gcc CXX=/usr/bin/g++ LD=/usr/bin/ld RANLIB=/usr/bin/ranlib AR=/usr/bin/ar"
    export CONF_ARGS="--disable-dependency-tracking --disable-silent-rules --prefix=/usr/local --disable-shared --enable-debug --without-cython"
    export ALT_CONF_ARGS="--disable-dependency-tracking --disable-silent-rules --prefix=/usr/local"
    if [[ $(uname -m) == "a"* && $(getconf LONG_BIT) == 64 ]]; then
        export LD_ARGS="-Wl,--allow-multiple-definition -L/usr/lib/aarch64-linux-gnu -lzstd -llzma -lbz2"
    elif [[ $(uname -m) == "a"* ]]; then
        export LD_ARGS="-Wl,--allow-multiple-definition -L/usr/lib/arm-linux-gnueabihf -lzstd -llzma -lbz2"
    else
        export LD_ARGS="-Wl,--allow-multiple-definition -L/usr/lib/x86_64-linux-gnu -lzstd -llzma -lbz2"
    fi

    echo "If prompted, enter your password"
    sudo echo -n ""
    echo "Compiling..."

    echo "Setting up build location and permissions"
    sudo rm -rf $FR_BASE || true
    sudo mkdir $FR_BASE
    sudo chown -R $USER:$USER $FR_BASE
    sudo chown -R $USER:$USER /usr/local
    sudo chown -R $USER:$USER /lib/udev/rules.d
    cd $FR_BASE
    echo "Done"

    echo "Downloading apt deps"
    sudo apt update
    sudo apt install -y aria2 curl build-essential checkinstall git autoconf automake libtool-bin pkg-config cmake libusb-1.0-0-dev libpng-dev libreadline-dev python3-dev autopoint
    sudo apt remove -y libssl-dev libzstd-dev || true # comment line for ssl3
    echo "Done"

    echo "Cloning git repos and other deps"
    git clone --filter=blob:none https://github.com/lzfse/lzfse
    git clone --filter=blob:none https://github.com/libimobiledevice/libplist
    git clone --filter=blob:none https://github.com/libimobiledevice/libimobiledevice-glue
    git clone --filter=blob:none https://github.com/libimobiledevice/libtatsu
    git clone --filter=blob:none https://github.com/LukeZGD/libusbmuxd
    git clone --filter=blob:none https://github.com/LukeZGD/libimobiledevice
    git clone --filter=blob:none https://github.com/LukeZGD/libirecovery
    # git clone --filter=blob:none https://github.com/libimobiledevice/idevicerestore # uncomment line for latest idr
    git clone --filter=blob:none https://github.com/nih-at/libzip -b v1.11.4
    # 7_65_3 for old ssl, 8_17_0 for pre-3.0 ssl, 8_21_0 for latest
    git clone --filter=blob:none https://github.com/curl/curl -b curl-7_65_3
    aria2c="aria2c -c -s 16 -x 16 -k 1M -j 1"
    $aria2c https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
    if [[ $1 == "old" ]]; then
        git clone --filter=blob:none --recursive https://github.com/LukeZGD/libipatcher
        git clone --filter=blob:none https://github.com/LukeZGD/daibutsuCFW
    elif [[ $1 == "new" ]]; then
        git clone --filter=blob:none https://github.com/tihmstar/img4tool
    fi
    git clone --filter=blob:none https://github.com/tihmstar/libgeneral
    git clone --filter=blob:none https://github.com/tihmstar/libfragmentzip

    # comment section for ssl3
    sslver="2.2.9"
    $aria2c https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-$sslver.tar.gz
    echo "Building libressl..."
    tar -zxvf libressl-$sslver.tar.gz
    cd libressl-$sslver
    ./configure
    make $JNUM
    make install

    echo "Building lzfse..."
    cd $FR_BASE
    cd lzfse
    make $JNUM $ALT_CC_ARGS
    make $JNUM install

    echo "Building libplist..."
    cd $FR_BASE
    cd libplist
    ./autogen.sh $CONF_ARGS $CC_ARGS
    make $JNUM
    make $JNUM install

    echo "Building libimobiledevice-glue..."
    cd $FR_BASE
    cd libimobiledevice-glue
    ./autogen.sh $CONF_ARGS $CC_ARGS
    make $JNUM
    make $JNUM install

    echo "Building curl..."
    cd $FR_BASE
    cd curl
    autoreconf -fi
    ./configure --disable-werror --disable-shared --with-openssl --without-libpsl
    make $JNUM
    make $JNUM install

    echo "Building libtatsu..."
    cd $FR_BASE
    cd libtatsu
    ./autogen.sh $CONF_ARGS $CC_ARGS
    make $JNUM
    make $JNUM install

    echo "Building libusbmuxd..."
    cd $FR_BASE
    cd libusbmuxd
    ./autogen.sh $CONF_ARGS $CC_ARGS
    make $JNUM
    make $JNUM install

    echo "Building libimobiledevice..."
    cd $FR_BASE
    cd libimobiledevice
    ./autogen.sh $CONF_ARGS $CC_ARGS LIBS="-L/usr/local/lib -lz -ldl"
    make $JNUM
    make $JNUM install

    echo "Building libirecovery..."
    cd $FR_BASE
    cd libirecovery
    ./autogen.sh $CONF_ARGS $CC_ARGS
    make $JNUM
    make $JNUM install

    echo "Building libzip..."
    cd $FR_BASE
    cd libzip
    sed -i 's/\"Build shared libraries\" ON/\"Build shared libraries\" OFF/g' CMakeLists.txt
    cmake $CC_ARGS .
    make $JNUM
    make $JNUM install

    echo "Building libbz2..."
    cd $FR_BASE
    tar -zxvf bzip2-1.0.8.tar.gz
    cd bzip2-1.0.8
    make $JNUM
    make $JNUM install

    if [[ $1 == "old" ]]; then
        aria2c https://github.com/LukeZGD/daibutsuCFW/releases/download/latest/xpwn_linux-$(uname -m).zip
        unzip xpwn_linux-$(uname -m).zip -d .
        cp bin/libxpwn.a bin/libcommon.a /usr/local/lib
        cd $FR_BASE
        cd daibutsuCFW/src/xpwn/include
        cp -R * /usr/local/include

        cd $FR_BASE
        echo "Building libipatcher..."
        cd libipatcher
        ./autogen.sh --disable-shared
        make $JNUM install LDFLAGS="$BEGIN_LDFLAGS"
        cd ..
    fi

    compdir=$FR_BASE
    instdir=/usr/local
    echo "Building libgeneral..."
    cd $compdir/libgeneral
    ./autogen.sh --enable-static --disable-shared --prefix="$instdir"
    make
    make install
    make clean

    echo "Building libfragmentzip..."
    cd $compdir/libfragmentzip
    ./autogen.sh --enable-static --disable-shared --prefix="$instdir"
    make CFLAGS="-I$instdir/include"
    make install
    make clean

    if [[ $1 == "new" ]]; then
        echo "Building img4tool..."
        cd $compdir/img4tool
        env LDFLAGS="-L$instdir/lib" ./autogen.sh --enable-static --disable-shared --prefix="$instdir"
        make
        make install
        make clean
    fi

    cd $FR_BASE
    zstd_ver=1.5.7
    aria2c https://github.com/facebook/zstd/releases/download/v$zstd_ver/zstd-$zstd_ver.tar.gz
    tar -zxvf zstd-$zstd_ver.tar.gz
    mkdir builddir
    cmake -B builddir \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DZSTD_BUILD_CONTRIB=ON \
        -DZSTD_BUILD_TESTS=ON \
        zstd-$zstd_ver/build/cmake
    cmake --build builddir
    cmake --install builddir

    echo "Building futurerestore!"
    cd $FR_BASE
    cd ..
    patch external/idevicerestore/configure.ac patch/idevicerestore/configure.patch
    patch external/idevicerestore/src/dfu.c patch/idevicerestore/dfu.patch
    patch external/idevicerestore/src/recovery.c patch/idevicerestore/recovery.patch
    patch external/idevicerestore/src/tss.c patch/idevicerestore/tss.patch
    patch external/img4tool/configure.ac patch/img4tool/configure.patch
    patch external/tsschecker/configure.ac patch/tsschecker/configure.patch
    ./autogen.sh $ALT_CONF_ARGS $CC_ARGS LDFLAGS="$LD_ARGS" LIBS="-llzma -lbz2 -lzstd -lcrypto -lz -ldl"
    make $JNUM
    mkdir -p bin/lib
    cp futurerestore/futurerestore bin/futurerestore_$1
    cp /usr/local/lib/libcrypto.so.35 /usr/local/lib/libssl.so.35 bin/lib/

elif [[ $OSTYPE == "msys" ]]; then
    platform="win"
    echo "* Platform: Windows MSYS2"

    STATIC=1
    # based on opa334's futurerestore compile script
    pacman -S --needed --noconfirm mingw-w64-x86_64-clang mingw-w64-x86_64-libzip mingw-w64-x86_64-brotli mingw-w64-x86_64-libpng mingw-w64-x86_64-python mingw-w64-x86_64-libunistring mingw-w64-x86_64-curl mingw-w64-x86_64-cython mingw-w64-x86_64-cmake
    pacman -S --needed --noconfirm make automake autoconf pkg-config openssl libtool m4 libidn2 git libunistring libunistring-devel python cython python-devel unzip zip
    export CC=gcc
    export CXX=g++
    export BEGIN_LDFLAGS="-Wl,--allow-multiple-definition"

    echo "Cloning git repos and other deps"
    git clone --filter=blob:none https://github.com/libimobiledevice/libplist
    git clone --filter=blob:none https://github.com/libimobiledevice/libusbmuxd
    git clone --filter=blob:none https://github.com/libimobiledevice/libimobiledevice
    git clone --filter=blob:none https://github.com/libimobiledevice/libirecovery
    git clone --filter=blob:none https://github.com/madler/zlib
    wget https://github.com/curl/curl/archive/refs/tags/curl-7_76_1.zip

    if [[ $STATIC == 1 ]]; then
        export STATIC_FLAG="--enable-static --disable-shared"
        export BEGIN_LDFLAGS="$BEGIN_LDFLAGS -all-static"

        git clone --filter=blob:none https://github.com/google/brotli
        wget https://ftp.gnu.org/gnu/libunistring/libunistring-0.9.10.tar.gz
        wget https://ftp.gnu.org/gnu/libidn/libidn2-2.3.0.tar.gz
        wget https://github.com/rockdaboot/libpsl/releases/download/0.21.1/libpsl-0.21.1.tar.gz
        wget https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
        wget https://tukaani.org/xz/xz-5.2.4.tar.gz
        wget https://libzip.org/download/libzip-1.5.1.tar.gz

        echo "Building brotli..."
        cd brotli
        git reset --hard 9801a2c
        git clean -fxd
        autoreconf -fi
        ./configure $STATIC_FLAG
        make $JNUM install LDFLAGS="$BEGIN_LDFLAGS"
        sed -i'' 's|Requires.private: libbrotlicommon >= 1.0.2|Requires.private: libbrotlicommon >= 0.0.0|' /mingw64/lib/pkgconfig/libbrotlidec.pc
        sed -i'' 's|Requires.private: libbrotlicommon >= 1.0.2|Requires.private: libbrotlicommon >= 0.0.0|' /mingw64/lib/pkgconfig/libbrotlienc.pc
        cd ..

        echo "Building libunistring..."
        tar -zxvf ./libunistring-0.9.10.tar.gz
        cd libunistring-0.9.10
        autoreconf -fi
        ./configure $STATIC_FLAG
        make $JNUM install LDFLAGS="$BEGIN_LDFLAGS"
        cd ..

        echo "Building libidn2..."
        tar -zxvf ./libidn2-2.3.0.tar.gz
        cd libidn2-2.3.0
        ./configure $STATIC_FLAG
        make $JNUM install LDFLAGS="$BEGIN_LDFLAGS"
        cd ..

        echo "Building libpsl..."
        tar -zxvf libpsl-0.21.1.tar.gz
        cd libpsl-0.21.1
        ./configure $STATIC_FLAG
        make $JNUM install LDFLAGS="$BEGIN_LDFLAGS"
        cd ..

        echo "Building bzip2..."
        tar -zxvf bzip2-1.0.8.tar.gz
        cd bzip2-1.0.8
        make $JNUM install LDFLAGS="--static -Wl,--allow-multiple-definition"
        cd ..

        echo "Building zlib..."
        cd zlib
        ./configure --static
        make $JNUM install LDFLAGS="$BEGIN_LDFLAGS"
        cd ..

        echo "Building libzip..."
        tar -zxvf libzip-1.5.1.tar.gz
        cd libzip-1.5.1
        mkdir new
        cd new
        cmake .. -DBUILD_SHARED_LIBS=OFF -G"MSYS Makefiles" -DCMAKE_INSTALL_PREFIX="/mingw64" -DENABLE_COMMONCRYPTO=OFF -DENABLE_GNUTLS=OFF -DENABLE_OPENSSL=OFF -DENABLE_MBEDTLS=OFF
        make $JNUM install LDFLAGS="$BEGIN_LDFLAGS"
        cd ../..
    fi

    echo "Building curl..."
    unzip curl-7_76_1.zip -d .
    cd curl-curl-7_76_1
    autoreconf -fi
    ./configure $STATIC_FLAG --with-schannel --without-ssl
    cd lib
    make $JNUM install CFLAGS="-DCURL_STATICLIB -DNGHTTP2_STATICLIB" LDFLAGS="$BEGIN_LDFLAGS"
    cd ../..

    echo "Building libplist..."
    cd libplist
    git reset --hard 787a449
    git clean -fxd
    ./autogen.sh $STATIC_FLAG --without-cython
    make $JNUM install LDFLAGS="$BEGIN_LDFLAGS"
    cd ..

    echo "Building libusbmuxd..."
    cd libusbmuxd
    git reset --hard 3eb50a0
    git clean -fxd
    ./autogen.sh $STATIC_FLAG
    make $JNUM install LDFLAGS="$BEGIN_LDFLAGS"
    cd ..

    echo "Building libimobiledevice..."
    cd libimobiledevice
    git reset --hard ca32415
    git clean -fxd
    ./autogen.sh $STATIC_FLAG --without-cython
    make $JNUM install LDFLAGS="$BEGIN_LDFLAGS"
    cd ..

    echo "Building libirecovery..."
    cd libirecovery
    git reset --hard 4793494
    git clean -fxd
    sed -i'' 's|ret = DeviceIoControl(client->handle, 0x220195, data, length, data, length, (PDWORD) transferred, NULL);|ret = DeviceIoControl(client->handle, 0x2201B6, data, length, data, length, (PDWORD) transferred, NULL);|' src/libirecovery.c
    ./autogen.sh $STATIC_FLAG
    make $JNUM install LDFLAGS="$BEGIN_LDFLAGS -ltermcap"
    cd ..

    echo "Building idevicerestore!"
    cd ..
    ./autogen.sh $STATIC_FLAG
    if [[ $STATIC == 1 ]]; then
        export curl_LIBS="$(curl-config --static-libs)"
        make $JNUM install CFLAGS="-DCURL_STATICLIB" LDFLAGS="$BEGIN_LDFLAGS" LIBS="-llzma -lbz2 -lbcrypt"
    else
        make $JNUM install LDFLAGS="$BEGIN_LDFLAGS"
    fi
    cp /mingw64/bin/idevicerestore bin/idevicerestore_$platform
fi

echo "Done!"
