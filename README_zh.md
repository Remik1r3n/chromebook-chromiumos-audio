# Chromebook ChromiumOS 音频

为运行基于 ChromiumOS 的系统（FydeOS、openFyde、ChromeOS Flex、CloudReady 等）的 Chrome 设备启用/修复音频支持。

目前仍处于实验阶段，请提前备份好数据并留好后路。欢迎报告任何问题！

## 要求
- 一台受支持的 x86_64 英特尔 Chromebook。酷睿7代以上的设备应该都可以正常工作。AMD 等其他设备尚未测试，但欢迎尝试。
- 装了基于 ChromiumOS 的操作系统。FydeOS/openFyde 是目前的主要目标，但其他系统也可能可以用。
  - 是的，Live USB 也可以用，但这只应该用于测试。
- 启用开发者模式，禁用 rootfs 验证，并且 / 可写。
  - 请按照说明完成这些操作。
  - 也许有更好的方式来修改系统，但目前这是必需的。
  - 遗憾的是，这样做之后你可能失去 OTA 支持 :(
- 具备基本的 Linux shell 知识。
- （可选但推荐）已下载来自 Google 的官方恢复镜像。它将用于制作你自己的音频包。
  - 我们包含了一个预构建的 `hatch` 包——它已在一些 Comet Lake 和 Alder Lake SOF Chromebook 上测试可正常工作。请只使用可信的包：安装程序会将其文件复制到系统根目录。

## 快速开始
注意：这里使用的是预构建的音频包。如果该包对你不起作用，请向下滚动，了解如何制作你自己的包。

1. 启动本地 root shell。

   启用开发者模式后，你可以通过 crosh 启动本地 shell（Ctrl+Alt+T，然后输入 `shell`），或通过 VT-2 shell（Ctrl+Alt+F2）启动。

   获得本地 `chronos` shell 后，你可以使用 `sudo -i` 获取 root shell。

2. 将根文件系统设为可写。

   * 对于 FydeOS，请参见 https://fydeos.com/help/knowledge-base/developer-options/developer-mode/disable-rootfs-verification/。
   * 对于其他基于 ChromiumOS 的系统，请参见 https://www.chromium.org/chromium-os/developer-library/guides/device/developer-mode/。

   禁用 rootfs 验证后，重启。

   然后你可以运行 `mount -o rw,remount /` 来修改系统。用 `touch /etc/testfile; rm /etc/testfile` 测试一下。

   如果没有看到任何错误消息，你现在就可以继续了。

3. 获取脚本。

   在 Chrome 中将仓库下载为 zip，并在“文件”应用中解压。使用 `cd /home/chronos/user/MyFiles/Downloads` 进入 Downloads 目录，并找到脚本文件目录。

   输入 `ls`，如果你看到所有脚本，请继续。

4. 运行脚本！

   ```sh
   sudo bash ./setup_audio.sh --pack ./packs/hatch-audio-pack.tar.gz --apply
   ```
   像这样运行音频设置脚本。根据需要更改路径参数。

   你可以保存输出，以备不时之需。

   然后重启并检查音频现在是否工作！

   如果不行：
   * 尝试制作你自己的音频包，而不是用我们做好的。
   * 使用下文所述的诊断输出提交 issue。

## 制作音频包
音频包是从官方 ChromeOS 固件中提取的一些文件，用于使声卡工作。

你需要一个完整的 Linux 环境，其中包含 `7z`、`python3` 以及 `tar` 等标准 shell 工具来制作它。不建议也不支持使用 ChromiumOS shell；Crostini 应该足够了。

下载适用于你设备的官方 ChromeOS 恢复镜像（推荐 https://cros.tech），并解压下载的归档文件以获得恢复 `.bin` 文件。

在仓库目录中，运行：

```sh
sh ./make_audio_pack.sh --recovery /path/to/recovery.bin --out ./my-audio-pack.tar.gz
```

要在不写入包的情况下检查提取的音频路径，请使用：

```sh
sh ./make_audio_pack.sh --recovery /path/to/recovery.bin --list-only
```

可选的 `--board <name>` 为包提供 board 的提示；从恢复镜像检测到的 board 可能覆盖它。

## 还原

还原功能仍处于实验阶段。安装程序会备份被覆盖的文件，并在 `/usr/local/chromebook-audio-backup/<board>/` 下跟踪新增的文件。
要还原，请打开 root shell，将根文件系统重新挂载为读写模式，然后运行：

```sh
sh ./setup_audio.sh --revert
reboot
```

安装程序使用检测到的 DMI board 名称来查找备份。如果你使用 `--board <name>` 应用了包，还原时请使用相同的选项。成功还原会删除备份。请保留单独的备份或恢复方式，以防实验性还原无法恢复所有内容。

## 故障排除

- 建议在尝试不同的包之前先还原现有安装。
- 检查根文件系统是否可写，以及包路径是否正确。安装中断可能会留下备份；检查输出，并在再次应用之前尝试实验性还原。
- 重启后收集诊断信息：
  ```sh
  sudo sh ./verify_audio.sh > audio-report.txt 2>&1
  ```
- 提交 issue 时，请包含你的 Chromebook 型号和板卡、操作系统和版本、使用的包、安装输出以及诊断报告。描述哪些音频设备工作或失败。在分享之前，请检查报告中是否包含敏感信息。

## 致谢与许可
由 Remi 制作。我编写的所有代码均以 BSD-3 许可证提供。其他文件按其各自原始许可证提供。

一些想法来自 [chromebook-linux-audio](https://github.com/WeirdTreeThing/chromebook-linux-audio) 和 [brunch](https://github.com/sebanc/brunch)。不过并未使用他们的代码。
