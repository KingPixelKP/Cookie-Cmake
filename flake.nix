{
  description = "Cookie-Cmake: Cargo-style package(), workspace() and dependencies() helpers for CMake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # `nix flake check` configures, builds and tests the fixture projects in tests/.
      checks = forAllSystems (pkgs: {
        fixture = pkgs.stdenv.mkDerivation {
          name = "cookie-cmake-fixture";
          src = self;
          cmakeDir = "../tests/fixture";
          nativeBuildInputs = [
            pkgs.cmake
            pkgs.ninja
          ];
          buildInputs = [
            pkgs.fmt
            pkgs.gtest
          ];
          doCheck = true;
          installPhase = ''
            ./bin/fixture | tee $out
            grep -qx 'hello, fixture' $out
          '';
        };

        # Same project as a Debug build: bounds checks must be active.
        fixture-debug = self.checks.${pkgs.stdenv.hostPlatform.system}.fixture.overrideAttrs {
          name = "cookie-cmake-fixture-debug";
          cmakeBuildType = "Debug";
        };

        empty = pkgs.runCommandCC "cookie-cmake-empty" { nativeBuildInputs = [ pkgs.cmake ]; } ''
          cmake -S ${self}/tests/empty -B build
          touch $out
        '';

        version-mismatch =
          pkgs.runCommandCC "cookie-cmake-version-mismatch"
            {
              nativeBuildInputs = [ pkgs.cmake ];
              buildInputs = [ pkgs.fmt ];
            }
            ''
              if cmake -S ${self}/tests/version-mismatch -B build > log 2>&1; then
                echo "configure succeeded although fmt is outside its version range" >&2
                exit 1
              fi
              grep -q 'version range' log
              touch $out
            '';

        # Uses a fake package (tests/components/prefix) that provides two components.
        components = pkgs.runCommandCC "cookie-cmake-components" { nativeBuildInputs = [ pkgs.cmake ]; } ''
          cmake -S ${self}/tests/components/ok -B ok | tee log
          grep -q 'Shapes 1.0.0 \[circle square\]' log

          if cmake -S ${self}/tests/components/missing -B missing > log 2>&1; then
            echo "configure succeeded although a required component is missing" >&2
            exit 1
          fi
          grep -q 'no component "hexagon"' log
          touch $out
        '';
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
