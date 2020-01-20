{ # The git revision here corresponds to the nixpkgs-unstable channel, which at
  # the time of this writing has GHC 8.6.5 as the default compiler (matching the
  # one used by stack.yaml). Use https://howoldis.herokuapp.com/ to determine
  # the current rev.
  pkgs ? import (builtins.fetchTarball "https://github.com/nixos/nixpkgs/archive/31ef3b8ec56.tar.gz") {}
  # Which GHC compiler to use.
  # To determine the list of compilers available run:
  #   nix-env -f "<nixpkgs>" -qaP -A haskell.compiler
, compiler ? "default"
}:
let
  haskellPackages =
    if compiler == "default"
      then pkgs.haskellPackages
      else pkgs.haskell.packages.${compiler};
  fetchGitHubArchive = owner: repo: rev:
    builtins.fetchTarball "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";

  # Cabal source dists should not contain symlinks targeting files outside its
  # directory. We replace such symlinks with their target here.
  unpackSymlinks = hp: pkgs.haskell.lib.overrideCabal hp (drv: {
    postUnpack = ''
      cp --remove-destination ${./README.md} $sourceRoot/README.md
      cp --remove-destination ${./LICENSE} $sourceRoot/LICENSE
      cp --remove-destination ${./CHANGELOG.md} $sourceRoot/CHANGELOG.md
    '';
  });

  # Summoner project derivation.
  projectDrv = (haskellPackages.override {
    overrides = self: super: with pkgs.haskell.lib; {
      summoner = unpackSymlinks (self.callCabal2nix "summoner" ./summoner-cli {});
      summoner-tui = unpackSymlinks (self.callCabal2nix "summoner-tui" ./summoner-tui {});
    };
  }).extend (pkgs.haskell.lib.packageSourceOverrides {
    relude = fetchGitHubArchive "kowainik" "relude"
      "bfb5f60dd41bd3e3a25ec222ce338f302f1f513e";
    tomland = fetchGitHubArchive "kowainik" "tomland"
      "d9b7a1dc344e41466788fe00d0ea016f04629ade";
    shellmet = fetchGitHubArchive "kowainik" "shellmet"
      "94b76e1864561edccd0c60311b45c7965cc50a23";
    optparse-applicative = fetchGitHubArchive "pcapriotti" "optparse-applicative"
      "5478fc16cbd3384c19e17348a17991896c724a3c";
  });

  # Summoner project shell.
  projectShell = projectDrv.shellFor {
    packages = p:
      [ p.summoner
        p.summoner-tui
      ];
    buildInputs =
      [ projectDrv.cabal-install
        # Dev dependencies below:
        projectDrv.ghcid
        # Runtime dependencies below;
        pkgs.curl
        pkgs.git
        pkgs.gitAndTools.hub
      ];
  };
in
if pkgs.lib.inNixShell then projectShell else projectDrv
