# pokemon-icat

This script is inspired by [this project](https://gitlab.com/phoneybadger/pokemon-colorscripts), but since the output heavily depends on the font of your terminal, I decided to make a script that shows a true PNG image of the Pokémon (of course, this script requires a terminal that supports images).

![Screenshot](screenshot.png)

## Requirements

**Important**: this program relies on [viuer](https://github.com/atanunq/viuer), so check if your terminal is supported first.

To use the script, you must first install the required dependencies:
- a supported terminal
- `Python 3.9.x` or newer
- Run:
    ```shell
    pip install -r requirements.txt
    ```

## Installation

After making sure that you have all of the requirements, run the following command:

```sh
git clone https://github.com/aflaag/pokemon-icat && cd pokemon-icat && sh install.sh
```

which should start the installation process of the script, by downloading every picture of every Pokémon.

Note that this script will add an environment variable `$POKEMON_ICAT_DATA` which is used by the binary at runtime. To achieve this, the script modifies the following files:
- `$HOME/.profile`
- `$HOME/.zprofile`
- `$HOME/.zshrc`
- `$HOME/.config/fish/config.fish`
Some users reported that a reboot was necessary for the program to function correctly.

Moreover, by default this will download every Pokémon with an upscaling factor of the original image of `3`, but if you want to change this behaviour run the last command with the option `--upscale <FACTOR>`, for example:

```sh
sh install.sh -u 15
```

### Arch

If you would like to contribute, an AUR package would be awesome!

### NixOS
This project includes a Home Manager module for easy integration into NixOS and standalone Home Manager setups.

#### 1. Add to your flake inputs

Add pokemon-icat as an input to your `flake.nix`:
```nix
{
      inputs = {
        pokemon-icat = {
          url = "github:aflaag/pokemon-icat"; 
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
}
```

#### 2. Import the Home Manager module

For **NixOS with Home Manager**:
```nix
outputs = { nixpkgs, home-manager, pokemon-icat, ... }: {
      nixosConfigurations.yourHost = nixpkgs.lib.nixosSystem {
        modules = [
          home-manager.nixosModules.home-manager
          {
            home-manager.users.yourUser = {
              imports = [
                pokemon-icat.homeManagerModules.default
              ];
            };
          }
        ];
      };
};
```


#### 3. Configure in your Home Manager config

Create a module (e.g., `pokemon.nix`):
```nix
{ config, lib, pkgs, ... }:
    with lib;
    {
      options.features.tools.pokemon = {
        enable = mkEnableOption "pokemon-icat";
      };
      
      config = mkIf config.features.tools.pokemon.enable {
        programs.pokemon-icat = {
          enable = true;
          
          # Pin sprites to a specific commit for reproducibility
          spritesCommit = "e1d237e02b8c0b385c644f184f26720909a82132";
          spritesHash = "sha256-3uD98h6VYepyOeIPaCdcTMFMVuwH8UvLl6scC8HMxu0=";
          upscaleFactor = 3.0;
        };
        
        # Optional: Show random Pokemon on shell start
        programs.zsh.initExtra = ''
              pokemon-icat
            '';
      };
    }
    ```

Then enable it:
```nix
features.tools.pokemon.enable = true;
    ```

### Finding the correct hashes

When using a different `spritesCommit`:

1. Browse commits at https://github.com/PokeAPI/sprites/commits/master
2. Copy the commit hash (40 characters)
3. Set `spritesCommit` to your chosen hash
4. Set `spritesHash` to a dummy value: `"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="`
5. Run `nixos-rebuild switch` or `home-manager switch`
6. Nix will fail and show the expected hash in the error message
7. Copy the hash from `got: sha256-...` and update `spritesHash`
8. Rebuild - it should now succeed


## Usage

To show a random Pokémon, simply run:

```sh
pokemon-icat
```

If you want to specify one or more generations in particular, simply add `--generations <GENERATIONS>` at the end, for example (**note**: the generations must be comma-separated, and trailing commas are not supported):

```sh
pokemon-icat -g 3,4,Hisui,5
```

Shiny Pokémons are supported too, and the default shiny rate can be changed as follows:

```sh
pokemon-icat --shiny-probability=10
```

If you want to show a Pokémon in particular, just use the `--pokemon <POKEMON>` flag, for example:

```sh
pokemon-icat -p charizard
```

and if you want to suppress the Pokémon info, use the `--quiet` flag:

```sh
pokemon-icat -p charizard -q
```

To check all the available options, use the `--help` option.

## Known issues

- Multiple images return an error while downloading because they do not exist
- Last DLC pokemons don't get downloaded (change the csv when this is fixed)
- Image `678.png` doesn't get downloaded

## would-like-to-do list

- AUR package (very requested)
- Nix package (WIP)
- rename the other images to include every available sprite
    - do they contain regional forms?

## Development

Check out [development.md](development.md)

