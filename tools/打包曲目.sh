#!/bin/zsh
# 把 midi/ 里的谱和 audio/ 里的同名伴奏打包进游戏文件，打开就在曲库里，不用拖。
# 伴奏会压到 64kbps AAC（不改原文件），两首 4 分钟的歌约 4 MB。
# 产出两份：
#   src/极夜落键.html  本地完整版（含伴奏音频）
#   index.html         公开版（不含伴奏，GitHub Pages 用；原曲录音有版权不能公开分发）
set -e
cd "$(dirname "$0")/.."
ROOT="$(pwd)"; HTML="$ROOT/src/极夜落键.html"; TMP="$(mktemp -d)"
build(){  # $1 = 输出文件  $2 = 1 表示不带音频
python3 - "$HTML" "$ROOT" "$TMP" "$2" "$1" <<'PY'
import sys, os, json, base64, glob, subprocess, re
html, root, tmp, noaudio, outpath = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1", sys.argv[5]
songs = []
for mid in sorted(glob.glob(os.path.join(root, "midi", "*.mid")) + glob.glob(os.path.join(root, "midi", "*.midi"))):
    name = os.path.splitext(os.path.basename(mid))[0]
    entry = {"name": name, "midi": base64.b64encode(open(mid, "rb").read()).decode()}
    if not noaudio:
        for ext in (".m4a", ".mp3", ".wav", ".flac", ".aac", ".ogg"):
            src = os.path.join(root, "audio", name + ext)
            if os.path.exists(src):
                out = os.path.join(tmp, name + ".m4a")
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-vn", "-c:a", "aac", "-b:a", "64k", "-movflags", "+faststart", out], check=True)
                entry["audio"] = base64.b64encode(open(out, "rb").read()).decode()
                break
    songs.append(entry)
    print(f"  {'♪ ' if 'audio' in entry else '   '}{name}  谱 {len(entry['midi'])//1024} KB" + (f"  伴奏 {len(entry['audio'])//1024} KB" if 'audio' in entry else ""))
s = open(html, encoding="utf-8").read()
a = s.index("/*BUNDLE-START*/") + len("/*BUNDLE-START*/"); b = s.index("/*BUNDLE-END*/")
s = s[:a] + "\nconst BUNDLE = " + json.dumps(songs, ensure_ascii=False) + ";\n" + s[b:]

# 钢琴采样 assets/piano/*.m4a → SAMPLES
samples = {}
for f in sorted(glob.glob(os.path.join(root, "assets", "piano", "*.m4a"))):
    samples[os.path.splitext(os.path.basename(f))[0]] = base64.b64encode(open(f, "rb").read()).decode()
a = s.index("/*SAMPLES-START*/") + len("/*SAMPLES-START*/"); b = s.index("/*SAMPLES-END*/")
s = s[:a] + "\nconst SAMPLES = " + json.dumps(samples) + ";\n" + s[b:]
print(f"  钢琴采样 {len(samples)} 个，{sum(len(v) for v in samples.values())//1024} KB")

open(outpath, "w", encoding="utf-8").write(s)
mb = len(s.encode()) / 1e6
print(f"写入 {len(songs)} 首 → {os.path.relpath(outpath, root)}  {mb:.1f} MB" + ("  ⚠ 超过 12 MB，在线版可能发不上去" if mb > 12 else ""))
PY
}
echo "— 本地完整版 —"; build "$HTML" 0
echo "— 公开版（无伴奏）—"; build "$ROOT/index.html" 1
rm -rf "$TMP"
