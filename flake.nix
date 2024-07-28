{
  description = "update-input";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs, ... }:
    let
      forAllSystems = function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] (system: function nixpkgs.legacyPackages.${system});
      script = pkgs: ''
        set -euo pipefail
        input=$(                                           \
          nix flake metadata --json                        \
          | ${pkgs.jq}/bin/jq -r ".locks.nodes.root.inputs | keys[]" \
          | printf "$(</dev/stdin) \nall" \
          | ${pkgs.fzf}/bin/fzf)
        if [[ $input == "all" ]];
        then
          nix flake update
        else
          nix flake lock --update-input $input
        fi
      '';
      _script_apply = ''
        while true; do
            read -p "apply? " yn
            case $yn in
                [Yy]* ) sudo nixos-rebuild switch --flake .#; break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
      '';
      script_apply = pkgs:
        (nixpkgs.lib.concatLines [ (script pkgs) _script_apply ]);
      script_apply_cycle = pkgs:
        (nixpkgs.lib.concatLines [
          "while true; do"
          (script pkgs)
          _script_apply
          ''
              read -p "continue?" cont
              case $cont in
                [Yy]* ) ;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
              esac
            done
          ''
        ]);
    in {
      overlays.default = final: prev: {
        inherit (self.packages.x86_64-linux) update-apply-cycle;
      };
      packages = forAllSystems (pkgs: {
        default = pkgs.writeShellScriptBin "update-input" (script pkgs);
        update-apply =
          pkgs.writeShellScriptBin "update-apply" (script_apply pkgs);
        update-apply-cycle = pkgs.writeShellScriptBin "update-apply-cycle"
          (script_apply_cycle pkgs);
      });
    };
}
