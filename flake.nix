{
  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    {
      devShells."${system}" = {
        default =
          let
            pkgs = import nixpkgs {
              inherit system;
            };
            crossPkgs = import nixpkgs {
              localSystem = "${system}";
              crossSystem = "riscv64-unknown-linux-gnu";

              # `riscv64-none-elf` needs to build toolchain locally and set a environment variable:
              # `make TOOLPREFIX=riscv64-unknown-none-elf- qemu`
              # or 'export TOOLPREFIX=riscv64-unknown-none-elf-' and then `make qemu`
              # crossSystem = "riscv64-none-elf";
            };
            fish-config = pkgs.writers.writeFish "fish-config" ''
              eval (functions fish_prompt | string replace "(prompt_login)" "dev" | string replace "function fish_prompt" "function fish_dev_prompt" | string collect)

              functions -c fish_prompt fish_default_prompt

              function fish_prompt
                if test -n "$IN_NIX_SHELL"
                  fish_dev_prompt
                end
                if test -z "$IN_NIX_SHELL"
                  fish_default_prompt
                end
              end

              function prepare
                rm -rf build
                cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
                cmake --build build -j$(nproc)
              end
            '';
            fish-wrapper = pkgs.writeShellApplication {
              name = "fish";
              text = ''
                ${pkgs.fish}/bin/fish -C "source ${fish-config}"
              '';
            };
          in
          pkgs.mkShell {
            packages =
              with pkgs;
              [
                git
                fish-wrapper
                nixd
                nixfmt-rfc-style
                helix
                qemu
                bc
              ]
              ++ (with crossPkgs; [
                buildPackages.gcc
                buildPackages.binutils
              ]);
            shellHook = ''
              # export TOOLPREFIX=riscv64-unknown-none-elf-
              exec fish
            '';
          };
      };
    };
}
