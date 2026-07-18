<p align="center">
  <img src="Resources/AppIcon.png" width="144" alt="声页图标">
</p>

<h1 align="center">声页</h1>

<p align="center">
  macOS 本地朗读阅读器 · 自动翻页 · 完全免费 · 开源 · 无广告
</p>

> [!IMPORTANT]
> **目前只提供 macOS 版本。** 不支持 iPhone、iPad、Windows、Android 或 Linux。

声页是一款轻量、纯净的原生 macOS 阅读软件。导入 EPUB 或 TXT 后，可以
单击任意一句话开始朗读；当前句子会自动高亮，朗读跨页时页面也会自动
翻到对应位置。朗读使用 macOS 自带语音引擎，在本机离线完成。

## 下载

前往 [Releases](https://github.com/Andy9223/ShengYe/releases/latest)
下载最新版：

- `VoicePage-v1.0.0-macOS-universal.dmg`：推荐安装包
- `VoicePage-v1.0.0-macOS-universal.zip`：备用压缩包

本版本完全免费，不需要注册、登录或激活密钥。

## 支持的设备与系统

| 项目 | 当前支持范围 |
|---|---|
| 平台 | 仅 macOS |
| 最低系统 | macOS 14 Sonoma |
| Apple 芯片 | 支持 M 系列 Mac |
| Intel 芯片 | 支持能够运行 macOS 14 的 Intel Mac |
| 安装包架构 | Universal 2（`arm64` + `x86_64`） |
| 电子书格式 | 无 DRM 的 EPUB 2/3、TXT |

系统可用朗读音色取决于这台 Mac 已安装的 macOS 系统语音。

## 核心功能

- 从任意一句话开始朗读，当前句子实时高亮
- 朗读跨页时自动翻页，无需手动操作
- 章节目录跳转、上一章和下一章快捷操作
- 字号变化后自动重新分页，只需左右翻页，无需上下滚动
- 调节系统音色、语速、字体大小和阅读页面亮度
- 白天、黑夜及跟随系统外观
- 10/20/30/60 分钟定时关闭
- 支持“读完本小节”“读完本章”后停止
- 全屏自适应，并显示电量、时间和阅读进度
- 键盘、触控板翻页与方向过渡动画
- 保存每本书的上次阅读位置
- 完全本地运行，不上传书籍和阅读记录

## 键盘与触控板

| 操作 | 功能 |
|---|---|
| `fn + F9` | 下一章 |
| `fn + F7` | 上一章 |
| `空格` | 播放 / 暂停 |
| `←` / `→` | 上一页 / 下一页 |
| 两指右滑 / 左滑 | 上一页 / 下一页 |
| `Esc` | 退出应用 |

## 安装方法

### 使用 DMG

1. 下载并打开 DMG。
2. 将“声页”拖入 `Applications` 文件夹。
3. 从“应用程序”中打开声页。

### 首次打开提示

当前 1.0.0 发布包尚未使用 Apple Developer ID 公证。若 macOS 阻止首次
启动，请在 Finder 中右键“声页”并选择“打开”；如仍被阻止，可前往
“系统设置 → 隐私与安全性”选择“仍要打开”。

## 从源代码构建

需要 macOS 14 或更高版本，以及 Apple Swift 5.10 或更高版本。

```sh
git clone https://github.com/Andy9223/ShengYe.git
cd ShengYe
zsh scripts/check-parser.sh
zsh scripts/build-app.sh
```

构建脚本会生成 Universal 2 的 `声页.app`、ZIP 和 DMG。

## 隐私与格式限制

- 朗读、分页和阅读进度都在本机完成。
- 不收集遥测，不使用云端朗读，不包含广告。
- Apple Books 中带 DRM 的已购内容无法导入。
- 复杂固定版式 EPUB 和漫画暂不支持。
- 页面亮度仅影响阅读页面，不改变系统屏幕亮度。

更多说明见 [隐私说明](PRIVACY.md)。

## 开源许可证

声页 1.0.0 及本仓库源代码按
[GNU General Public License v3.0](LICENSE) 发布。你可以运行、研究、
修改和再分发，但分发衍生版本时也必须遵守 GPL-3.0 并提供对应源代码。

Copyright © 2026 Andy9223.
