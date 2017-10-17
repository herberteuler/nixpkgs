{ stdenv
, lib
, fetchurl
, alsaLib
, atk
, bzip2
, cairo
, curl
, expat
, fontconfig
, freetype
, gdk_pixbuf
, glib
, glibc
, graphite2
, gtk2
, harfbuzz
, libICE
, libSM
, libX11
, libXau
, libXcomposite
, libXcursor
, libXdamage
, libXdmcp
, libXext
, libXfixes
, libXi
, libXinerama
, libXrandr
, libXrender
, libXt
, libXxf86vm
, libdrm
, libffi
, libpng
, libvdpau
, libxcb
, libxshmfence
, nspr
, nss
, pango
, pcre
, pixman
, zlib
, unzip
, debug ? false
}:

let
  arch =
    if stdenv.system == "x86_64-linux" then
      "x86_64"
    else throw "Flash Player is not supported on this platform";
in
stdenv.mkDerivation rec {
  name = "flashplayer-standalone-${version}";
  version = "27.0.0.159";

  src = fetchurl {
    url = "https://fpdownload.macromedia.com/pub/flashplayer/installers/archive/fp_${version}_archive.zip";
    sha256 = "079623a107f4c05ab19f3bcd73c2eb9ee832c14223ef7e807a7cb5fa30b315ac";
  };

  nativeBuildInputs = [ unzip ];

  sourceRoot = ".";

  dontStrip = true;
  dontPatchELF = true;

  preferLocalBuild = true;

  postUnpack = if debug then ''
    dir=$(ls | grep -v env-vars | grep debug)
    file=$(echo $dir/flashplayer*_linux_sa_debug.${arch}.tar.gz)
    echo unpacking $file
    tar xf $file
  '' else ''
    dir=$(ls | grep -v env-vars | grep -v debug)
    file=$(echo $dir/flashplayer*_linux_sa.${arch}.tar.gz)
    echo unpacking $file
    tar xf $file
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp -pv flashplayer${lib.optionalString debug "debugger"} $out/bin

    patchelf \
      --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) \
      --set-rpath "$rpath" \
      $out/bin/flashplayer${lib.optionalString debug "debugger"}
  '';

  rpath = lib.makeLibraryPath
    [ stdenv.cc.cc
      alsaLib atk bzip2 cairo curl expat fontconfig freetype gdk_pixbuf glib
      glibc graphite2 gtk2 harfbuzz libICE libSM libX11 libXau libXcomposite
      libXcursor libXdamage libXdmcp libXext libXfixes libXi libXinerama
      libXrandr libXrender libXt libXxf86vm libdrm libffi libpng libvdpau
      libxcb libxshmfence nspr nss pango pcre pixman zlib
    ];

  meta = {
    description = "Adobe Flash Player standalone executable";
    homepage = https://www.adobe.com/support/flashplayer/debug_downloads.html;
    license = stdenv.lib.licenses.unfree;
    maintainers = [];
    platforms = [ "x86_64-linux" ];
  };
}
