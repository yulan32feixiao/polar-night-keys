# 极夜落键 · Polar Night Keys

一个为**零乐理基础**设计的下落式钢琴音游。打开网页就能玩，电脑用键盘，iPad 用触屏。

**▶ 在线玩：https://yulan32feixiao.github.io/polar-night-keys/**

## 它和别的音游有什么不一样

- **一首曲子用到几个音，就只用几个键。** 旋律只有 7 个音，你就只按 `A S D F G H J`。
- **等待我模式**：曲子停下来等你按对才走，永远不会失败。
- **左手伴奏程序自动弹**，你只管旋律。
- 真钢琴采样、按住持续、松手止音、延音踏板（Shift）。
- 载入任何 MIDI 文件自动生成谱面，自动分左右手、忽略鼓轨。
- 内置 7 首：Nod-Krai、To Light the Aeon Dark（原神挪德卡莱，人声旋律自动转谱）、致爱丽丝、卡农、月光奏鸣曲、天空之城、River Flows in You。

## 怎么玩

1. 打开链接，点「开始演奏」
2. 底部「曲库 · 切换歌曲」选歌
3. 把自己的 `.mid` 文件拖进页面即可添加；同名音频会自动配成伴奏（公开版不含原曲音频）

键位：10 个音以内用中间一排 `A…;`；更多时用标准两排——下排 `Z X C V B N M` 白键 + `S D G H J` 黑键，`Q` 那排高一个八度（Synthesia / FL Studio 同款）。

## 自己出谱

`tools/B站转关卡.sh BV号 "歌名"`：下载 B 站音频 → Demucs 分离人声 → basic-pitch 转旋律 MIDI。详见 `docs/说明.md`。

## 致谢 / 授权

- 钢琴采样：[Salamander Grand Piano](https://github.com/sfzinstruments/SalamanderGrandPiano) by Alexander Holm，CC BY 3.0（经 [tonejs-instruments](https://github.com/nbrosowsky/tonejs-instruments) 的 mp3 版转码）
- 公版 MIDI 来自 bitmidi.com
- 原神曲目的谱面为人声旋律的自动转谱，仅供个人练习；公开版不含任何原曲录音
- 游戏代码：MIT
