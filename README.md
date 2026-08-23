# AzerothCore-portable-builds

Always wanted to play on your own local World of Warcraft 3.3.5a server, but were intimidated by the compilation and installation process? You can now do this easily.

This repository contains fully portable and ready-to-use AzerothCore builds for Linux that should work on most Linux distributions. By default the builds include `mod-playerbots`, `mod-individual-progression` and a few other modules.

It also includes a script (`build-server.sh`) for creating such portable builds for those who want to customize things or simply have full control over the build environment.

## How to use

1. Download and extract a ready-to-use build from the releases page.
2. Run `start-server.sh` from the server directory and wait a few seconds or a few minutes (depending on how fast your CPU and your storage device is). When the server is fully initialized and is ready-to-use, you will see `World Initialized In [TIME]` near the end of the terminal output among other lines.
3. Create an account that will be used to log into the server from the game. To do this, type `account create username password` (for example, `account create gamer gamer`) in the same terminal session (window) and press Enter key on your keyboard. You will see `Account created` message in case of success.
4. Change realmlist in your game client to `127.0.0.1`. To do this, open `Data/enGB/realmlist.wtf` (or your language code instead of enGB) via any text editor, remove everything from it, put the single `set realmlist 127.0.0.1` line and save it.
5. Done. Now you can run the game and log in using the account you created.

To stop the server, execute the `server exit` command on it.

## Requirements

1. The game client of version 3.3.5a is required to play on the server. On Linux you can run it via Wine, it works out of the box.
2. Linux kernel version 4.4 or higher is required, older kernel versions are not supported. Most modern Linux distributions come with a kernel of sufficient version out of the box.

I tested the builds on Arch Linux, Debian 13 and Alpine Linux, and they worked fine on all of them. If you have any issues running the build on your Linux distribution, please let me know.

## Server configuration

You can customize the server to your liking by editing the configuration files in the etc directory.

## Mutiplayer

Playing solo works out of the box. If you want other players on your local network to be able to join your server, you need to connect to the database via tools like `DBeaver` or `HeidiSQL` (port is 3308, login is root, password is empty) and change `127.0.0.1` in `acore_auth.realmlist.address` table to the local IP-address of the computer on which the server is running. Also change realmlist to the same IP-address in all your game clients. Restart the server after editing the database.

## Building

The `build-server.sh` script has only been tested on Arch Linux and is not guaranteed to work on other Linux distributions. However, the AzerothCore builds it creates should work on most other Linux distributions.

These packages are required (on Arch Linux) for the `build-server.sh` to work properly: `gcc boost cmake git libaio numactl`
