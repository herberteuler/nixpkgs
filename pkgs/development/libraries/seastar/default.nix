{ stdenv, fetchgit
, python3, gcc6, ninja, ragel, cmake, libtool
, boost, coreutils, cryptopp, gnutls, hwloc, libaio, libpciaccess, libunwind
, libxfs, libxml2, lksctp-tools, lz4, numactl, protobuf, linuxPackages }:

stdenv.mkDerivation {
  name = "seastar";
  src = fetchgit {
    url = "https://github.com/scylladb/seastar";
    rev = "11ad0b1";
  };
  nativeBuildInputs = [ python3 gcc6 ninja ragel cmake libtool ];
  buildInputs = [ boost coreutils cryptopp gnutls hwloc libaio libpciaccess
                  libunwind libxfs libxml2 lksctp-tools lz4 numactl protobuf
                  linuxPackages.systemtap ];
  patches = [ ./ignored-return-value.patch ./nix-stdenv.patch ];
  configure = ''
    python3 configure.py
  '';
  configureFlags = [
    "--cflags" " -I${linuxPackages.systemtap}/include"
    "--cflags" " -I${hwloc}/include" "--cflags" " -I${numactl}/include"
    "--ldflags" " -L${hwloc}/lib" "--ldflags" " -L${numactl}/lib"
    "--pie" "--so" "--mode" "all"
  ];
  dontAddPrefix = true;
  buildPhase = ''
    ninja -j6
  '';
}
