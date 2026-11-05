# Chromebook ChromiumOS Audio

Enable/fix audio support on Chrome devices running ChromiumOS-based systems (FydeOS, openFyde, ChromeOS Flex, CloudReady, etc.)

Currently experimental, back up important data and keep a recovery method available. Reports of any issues are welcome!

## Requirements
- A supported x86_64 Intel Chromebook. Anything newer than Kaby Lake should work fine. Others like AMD devices have not been tested, but you're welcome to try it.
- A ChromiumOS-based OS installed. FydeOS/openFyde is our main goal, but other OS may also work.
  - Yes, a Live USB session will also work with proper configuration. But it should only be used for testing.
- Developer Mode is enabled, rootfs verification is disabled, and / is writable. 
  - Follow the instructions to do that. 
  - Maybe there are better ways to modify the system, but currently this is required. 
  - Sadly, you may lose OTA support after that :(
- Basic knowledge of the Linux shell.
- (Optional but recommended) Your official recovery image from Google downloaded. It will be used to make your own audio pack.
  - We included a pre-built `hatch` pack -- it has been tested on some Comet Lake and Alder Lake SOF Chromebooks to work fine. Use only trusted packs: the installer copies their files into the system root.

## Quick Start
Note: This uses a prebuilt audio pack. If that pack doesn't work for you, scroll down to make yours first.

1. Launch a local root shell.

   After enabling Developer Mode, you can launch a local shell with crosh (Ctrl+Alt+T, then type `shell`) or with VT-2 shell (Ctrl+Alt+F2). 

   Once you get a local `chronos` shell, you can use `sudo -i` to get a root shell.

2. Set the root filesystem writable.

   * For FydeOS, see https://fydeos.com/help/knowledge-base/developer-options/developer-mode/disable-rootfs-verification/.
   * For other ChromiumOS-based system, see https://www.chromium.org/chromium-os/developer-library/guides/device/developer-mode/.

   Once you have disabled rootfs verification, reboot.

   Then you can run `mount -o rw,remount /` to make changes to your system. Test it with `touch /etc/testfile; rm /etc/testfile`.

   If you didn't see any error message, you're now good to go ahead.

3. Get the script.

   Download the repo as a zip in Chrome and unzip it in the Files app. Use `cd /home/chronos/user/MyFiles/Downloads` to enter Downloads directory, and find the script files directory.

   Type `ls`, if you see all the scripts, continue.

4. Run the script!

   ```sh
   sudo bash ./setup_audio.sh --pack ./packs/hatch-audio-pack.tar.gz --apply
   ```
   Run the audio setup script like that. Change the path arguments when needed.

   You can save the output just in case we need it.

   Then reboot and check if audio works now! 

   If it's not: 
   * Try to make your audio pack instead of use ours.
   * File an issue with the diagnostic output described below.

## Make an audio pack
An audio pack is some files extracted from official ChromeOS firmware to make sound card working.

You'll need a full Linux environment with `7z`, `python3`, and standard shell utilities like `tar` to make it. ChromiumOS shell is not recommended and not supported; Crostini should be enough.

Download the official ChromeOS recovery image for your device (https://cros.tech is a good place to find it) and extract the downloaded archive to obtain the recovery `.bin` file. 

From the repository directory, run:

```sh
sh ./make_audio_pack.sh --recovery /path/to/recovery.bin --out ./my-audio-pack.tar.gz
```

To inspect extracted audio paths without writing a pack, use:

```sh
sh ./make_audio_pack.sh --recovery /path/to/recovery.bin --list-only
```

The optional `--board <name>` supplies a board hint for the pack manifest; a board detected from the recovery image can override it. 

## Revert

Reverting is experimental. The installer backs up overwritten files and tracks added files under `/usr/local/chromebook-audio-backup/<board>/`.
To revert, open a root shell, remount the root filesystem read-write, and run:

```sh
sh ./setup_audio.sh --revert
reboot
```

The installer uses the detected DMI board name to find the backup. If you applied the pack with `--board <name>`, use the same option when reverting. A successful revert removes the backup. Keep a separate backup or recovery method in case the experimental revert does not restore everything.

## Troubleshooting

- It is recommended to revert the existing installation before trying a different pack.
- Check that the root filesystem is writable and that the pack path is correct. An interrupted installation may leave a backup; inspect the output and try the experimental revert before applying again.
- Collect diagnostics after rebooting:
  ```sh
  sudo sh ./verify_audio.sh > audio-report.txt 2>&1
  ```
- When filing an issue, include your Chromebook model and board, OS and version, pack used, installation output, and diagnostic report. Describe which audio devices work or fail. Review the report for sensitive information before sharing it.

## Credits & License
Made by Remi. All code written by me is provided under the BSD-3 license. Other files are provided under their respective original licenses.

Some ideas from [chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio) and [brunch](https://github.com/sebanc/brunch). Their code was not used, though.

