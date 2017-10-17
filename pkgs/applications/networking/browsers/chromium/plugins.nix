{ stdenv
, jshon
, fetchurl
, enablePepperFlash ? false
, enableWideVine ? false
, unzip
, upstream-info
}:

with stdenv.lib;

let
  mkrpath = p: "${makeSearchPathOutput "lib" "lib64" p}:${makeLibraryPath p}";

  # Generate a shell fragment that emits flags appended to the
  # final makeWrapper call for wrapping the browser's main binary.
  #
  # Note that this is shell-escaped so that only the variable specified
  # by the "output" attribute is substituted.
  mkPluginInfo = { output ? "out", allowedVars ? [ output ]
                 , flags ? [], envVars ? {}
                 }: let
    shSearch = ["'"] ++ map (var: "@${var}@") allowedVars;
    shReplace = ["'\\''"] ++ map (var: "'\"\${${var}}\"'") allowedVars;
    # We need to triple-escape "val":
    #  * First because makeWrapper doesn't do any quoting of its arguments by
    #    itself.
    #  * Second because it's passed to the makeWrapper call separated by IFS but
    #    not by the _real_ arguments, for example the Widevine plugin flags
    #    contain spaces, so they would end up as separate arguments.
    #  * Third in order to be correctly quoted for the "echo" call below.
    shEsc = val: "'${replaceStrings ["'"] ["'\\''"] val}'";
    mkSh = val: "'${replaceStrings shSearch shReplace (shEsc val)}'";
    mkFlag = flag: ["--add-flags" (shEsc flag)];
    mkEnvVar = key: val: ["--set" (shEsc key) (shEsc val)];
    envList = mapAttrsToList mkEnvVar envVars;
    quoted = map mkSh (flatten ((map mkFlag flags) ++ envList));
  in ''
    mkdir -p "''$${output}/nix-support"
    echo ${toString quoted} > "''$${output}/nix-support/wrapper-flags"
  '';

  widevine = stdenv.mkDerivation {
    name = "chromium-binary-plugin-widevine";

    src = upstream-info.binary;

    phases = [ "unpackPhase" "patchPhase" "installPhase" "checkPhase" ];

    unpackCmd = let
      chan = if upstream-info.channel == "dev"    then "chrome-unstable"
        else if upstream-info.channel == "stable" then "chrome"
        else "chrome-${upstream-info.channel}";
    in ''
      mkdir -p plugins
      ar p "$src" data.tar.xz | tar xJ -C plugins --strip-components=4 \
        ./opt/google/${chan}/libwidevinecdm.so \
        ./opt/google/${chan}/libwidevinecdmadapter.so
    '';

    doCheck = true;
    checkPhase = ''
      ! find -iname '*.so' -exec ldd {} + | grep 'not found'
    '';

    patchPhase = ''
      for sofile in libwidevinecdm.so libwidevinecdmadapter.so; do
        chmod +x "$sofile"
        patchelf --set-rpath "${mkrpath [ stdenv.cc.cc ]}" "$sofile"
      done

      patchelf --set-rpath "$out/lib:${mkrpath [ stdenv.cc.cc ]}" \
        libwidevinecdmadapter.so
    '';

    installPhase = let
      wvName = "Widevine Content Decryption Module";
      wvDescription = "Playback of encrypted HTML audio/video content";
      wvMimeTypes = "application/x-ppapi-widevine-cdm";
      wvModule = "@out@/lib/libwidevinecdmadapter.so";
      wvInfo = "#${wvName}#${wvDescription};${wvMimeTypes}";
    in ''
      install -vD libwidevinecdm.so \
        "$out/lib/libwidevinecdm.so"
      install -vD libwidevinecdmadapter.so \
        "$out/lib/libwidevinecdmadapter.so"

      ${mkPluginInfo {
        flags = [ "--register-pepper-plugins=${wvModule}${wvInfo}" ];
        envVars.NIX_CHROMIUM_PLUGIN_PATH_WIDEVINE = "@out@/lib";
      }}
    '';
  };

  flash = stdenv.mkDerivation rec {
    name = "flashplayer-ppapi-${version}";
    version = "27.0.0.159";

    arch =
      if stdenv.system == "x86_64-linux" then
        "x86_64"
      else if stdenv.system == "i686-linux" then
        "i386"
      else
        throw "Flash Player is not supported on this platform";

    src = fetchurl {
      url = "https://fpdownload.macromedia.com/pub/flashplayer/installers/archive/fp_${version}_archive.zip";
      sha256 = "079623a107f4c05ab19f3bcd73c2eb9ee832c14223ef7e807a7cb5fa30b315ac";
    };

    postUnpack = ''
      dir=$(ls | grep -v env-vars | grep -v debug)
      file=$(echo $dir/flashplayer*_linuxpep.${arch}.tar.gz)
      echo unpacking $file
      tar xf $file
    '';

    patchPhase = ''
      chmod +x libpepflashplayer.so
      patchelf --set-rpath "${mkrpath [ stdenv.cc.cc ]}" libpepflashplayer.so
    '';

    doCheck = true;
    checkPhase = ''
      ! find -iname '*.so' -exec ldd {} + | grep 'not found'
    '';

    installPhase = ''
      flashVersion="$(
        "${jshon}/bin/jshon" -F manifest.json -e version -u
      )"

      install -vD libpepflashplayer.so "$out/lib/libpepflashplayer.so"

      ${mkPluginInfo {
        allowedVars = [ "out" "flashVersion" ];
        flags = [
          "--ppapi-flash-path=@out@/lib/libpepflashplayer.so"
          "--ppapi-flash-version=@flashVersion@"
        ];
      }}
    '';

    dontStrip = true;
    dontPatchElf = true;

    nativeBuildInputs = [ unzip ];
    sourceRoot = ".";
  };

in {
  enabled = optional enableWideVine widevine
         ++ optional enablePepperFlash flash;
}
