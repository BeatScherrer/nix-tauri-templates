{
  description = "A Tauri Angular Android development flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    android.url = "github:tadfisher/android-nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      android,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        function:
        nixpkgs.lib.genAttrs systems (
          system:
          function ({
            pkgs = import nixpkgs {
              inherit system;
              overlays = [
                rust-overlay.overlays.default
                self.overlay
              ];
              config = {
                allowUnfree = true;
                android_sdk.accept_license = true;
              };
            };
            inherit system;
          })
        );
    in
    {
      overlay = final: prev: {
        inherit (self.packages.${final.system}) android-sdk android-studio;
      };

      packages = forAllSystems (
        { pkgs, system }:
        {
          android-sdk = android.sdk.${system} (
            sdkPkgs:
            with sdkPkgs;
            [
              # Useful packages for building and testing.
              build-tools-34-0-0
              cmdline-tools-latest
              emulator
              platform-tools
              platforms-android-34

              # Other useful packages for a development environment.
              ndk-26-1-10909125
              # skiaparser-3
              # sources-android-34
            ]
            ++ pkgs.lib.optionals (system == "aarch64-darwin") [
              # system-images-android-34-google-apis-arm64-v8a
              # system-images-android-34-google-apis-playstore-arm64-v8a
            ]
            ++ pkgs.lib.optionals (system == "x86_64-darwin" || system == "x86_64-linux") [
              # system-images-android-34-google-apis-x86-64
              # system-images-android-34-google-apis-playstore-x86-64
            ]
          );
        }
        // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
          # Android Studio in nixpkgs is currently packaged for x86_64-linux only.
          android-studio = pkgs.androidStudioPackages.stable;
          # android-studio = pkgs.androidStudioPackages.beta;
          # android-studio = pkgs.androidStudioPackages.preview;
          # android-studio = pkgs.androidStudioPackage.canary;
        }
      );

      devShells = forAllSystems (
        { pkgs, ... }:
        {
          default =
            with pkgs;
            mkShell rec {
              motd = ''
                Welcome to the Tauri Android App Development environment.
              '';

              nativeBuildInputs = with pkgs; [
                pkg-config
                gobject-introspection
                cargo
                cargo-tauri
                nodejs
              ];

              buildInputs = [
                #-- tauri
                (rust-bin.stable.latest.default.override {
                  targets = [
                    "aarch64-linux-android"
                    "x86_64-linux-android"
                    "armv7-linux-androideabi"
                    "i686-linux-android"
                  ];
                })
                at-spi2-atk
                nodejs
                atkmm
                cairo
                gdk-pixbuf
                harfbuzz
                pnpm
                nodePackages."@angular/cli"
                curl
                wget
                pkg-config
                dbus
                openssl
                glib
                gtk3
                libsoup_2_4
                webkitgtk_4_1
                librsvg
                pango
                # android utilities
                androidenv.androidPkgs.platform-tools # adb
                apksigner
                zulu
                self.packages.${system}.android-studio
                self.packages.${system}.android-sdk

                #-- other tools
                just
                eza
                fd

                # LSPs
                vscode-langservers-extracted
                typescript-language-server
                nodePackages.prettier
                nodePackages.vscode-langservers-extracted
                rust-analyzer
                emmet-ls
              ];

              shellHook = ''
                alias ls=eza
                alias find=fd

                pnpm install
              '';

              LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH";
              OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include/openssl";
              OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
              OPENSSL_ROOT_DIR = "${pkgs.openssl.out}";

              GIO_MODULE_DIR = "${pkgs.glib-networking}/lib/gio/modules/";

              # Android
              ANDROID_HOME = "${pkgs.android-sdk}/share/android-sdk";
              ANDROID_SDK_ROOT = "${android-sdk}/share/android-sdk";
              JAVA_HOME = jdk.home;
              NDK_HOME = "${android-sdk}/share/android-sdk/ndk/26.1.10909125";
              GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${android-sdk}/share/android-sdk/build-tools/34.0.0/aapt2";

              # other?
              XDG_DATA_DIRS = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$XDG_DATA_DIRS";
            };
        }
      );
    };
}
