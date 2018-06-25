{ stdenv, lib, fetchurl
, SDL, dwarf-fortress-unfuck

# Our own "unfuck" libs for macOS
, ncurses, fmodex, gcc
}:

with lib;

let
  baseVersion = "44";
  patchVersion = "11";
  dfVersion = "0.${baseVersion}.${patchVersion}";

  libpath = makeLibraryPath [ stdenv.cc.cc stdenv.cc.libc dwarf-fortress-unfuck SDL ];

  homepage = http://www.bay12games.com/dwarves/;

  # Other srcs are avilable like 32-bit mac & win, but I have only
  # included the ones most likely to be needed by Nixpkgs users.
  srcs = {
    "x86_64-linux" = fetchurl {
      url = "${homepage}df_${baseVersion}_${patchVersion}_linux.tar.bz2";
      sha256 = "1qizfkxl2k6pn70is4vz94q4k55bc3pm13b2r6yqi6lw1cnna4sf";
    };
    "i686-linux" = fetchurl {
      url = "${homepage}df_${baseVersion}_${patchVersion}_linux32.tar.bz2";
      sha256 = "11m39lfyrsxlw1g7f269q7fzwichg06l21fxhqzgvlvmzmxsf8q5";
    };
    "x86_64-darwin" = fetchurl {
      url = "${homepage}df_${baseVersion}_${patchVersion}_osx.tar.bz2";
      sha256 = "1cxckszjh5fi9czywr1kl5kj9zxzaszhqdal5gd8ww0ihcbl7fcd";
    };
  };

in

assert dwarf-fortress-unfuck != null ->
       dwarf-fortress-unfuck.dfVersion == dfVersion;

stdenv.mkDerivation {
  name = "dwarf-fortress-original-${dfVersion}";

  src = if builtins.hasAttr stdenv.system srcs
        then builtins.getAttr stdenv.system srcs
        else throw "Unsupported systems";

  installPhase = ''
    mkdir -p $out
    cp -r * $out
    rm $out/libs/lib*

    exe=$out/${if stdenv.isLinux then "libs/Dwarf_Fortress"
                                 else "dwarfort.exe"}

    # Store the original hash
    md5sum $exe | awk '{ print $1 }' > $out/hash.md5.orig
  '' + optionalString stdenv.isLinux ''
    patchelf \
      --set-interpreter $(cat ${stdenv.cc}/nix-support/dynamic-linker) \
      --set-rpath "${libpath}" \
      $exe
  '' + optionalString stdenv.isDarwin ''
    # My custom unfucked dwarfort.exe for macOS. Can't use
    # absolute paths because original doesn't have enough
    # header space. Someone plz break into Tarn's house & put
    # -headerpad_max_install_names into his LDFLAGS.

    ln -s ${getLib ncurses}/lib/libncurses.dylib $out/libs
    ln -s ${getLib gcc.cc}/lib/libstdc++.6.dylib $out/libs
    ln -s ${getLib fmodex}/lib/libfmodex.dylib $out/libs

    install_name_tool \
      -change /usr/lib/libncurses.5.4.dylib \
              @executable_path/libs/libncurses.dylib \
      -change /usr/local/lib/x86_64/libstdc++.6.dylib \
              @executable_path/libs/libstdc++.6.dylib \
      $exe
  '' + ''
    # Store the new hash
    md5sum $exe | awk '{ print $1 }' > $out/hash.md5
  '';

  passthru = { inherit baseVersion patchVersion dfVersion; };

  meta = {
    description = "A single-player fantasy game with a randomly generated adventure world";
    inherit homepage;
    license = licenses.unfreeRedistributable;
    platforms = attrNames srcs;
    maintainers = with maintainers; [ a1russell robbinch roconnor the-kenny abbradar numinit ];
  };
}
