#!/bin/zsh
# 一条命令：B 站视频 → 关卡素材
#   1) 下载音频到 audio/<歌名>.m4a                 （永远会做，当伴奏用）
#   2) 如果装了转谱环境：分离人声 → 转成旋律 MIDI 到 midi/<歌名>.mid
#
# 用法：  ./B站转关卡.sh <BV号或链接> <歌名> [分P序号]
# 例子：  ./B站转关卡.sh BV1cyWxzQEwV "Nod-Krai"
#         ./B站转关卡.sh BV16EhRzmEgr "To Light the Aeon Dark" 2    ← 多P视频取第2P
set -e
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
ENV="$ROOT/tools/.env"        # yt-dlp
TENV="$ROOT/tools/.tenv"      # Demucs + basic-pitch（Python 3.11）
if [[ -z "$1" || -z "$2" ]]; then
  echo "用法: $0 <BV号或B站链接> <歌名>"; exit 1
fi
IN="$1"; NAME="$2"; PART="${3:-1}"
[[ "$IN" == BV* ]] && IN="https://www.bilibili.com/video/$IN"
[[ "$IN" == *\?* ]] || IN="$IN?p=$PART"
[[ -x "$ENV/bin/yt-dlp" ]] || { echo "缺 tools/.env，运行一次 ./tools/安装转谱环境.sh"; exit 1; }

AUDIO="$ROOT/audio/$NAME.m4a"
if [[ -s "$AUDIO" ]]; then
  echo "▶ 1/3 音频已存在，跳过下载：$AUDIO"
else
echo "▶ 1/3 取音频地址 …"
URL="$("$ENV/bin/yt-dlp" --no-warnings --no-playlist -f ba --get-url "$IN" | head -1)"
[[ -n "$URL" ]] || { echo "   ✗ 拿不到地址，链接对吗？"; exit 1; }
PATHQ="${URL#https://*/}"

# B 站给海外 IP 分配的 akamaized 节点会返回 567，签名 URL 在各镜像之间通用，所以挨个试
MIRRORS=("${URL%%/${PATHQ}}" https://upos-sz-mirrorcos.bilivideo.com https://upos-sz-mirrorali.bilivideo.com
         https://upos-sz-mirrorhw.bilivideo.com https://upos-sz-mirroraliov.bilivideo.com
         https://upos-sz-mirrorhwo1.bilivideo.com https://upos-sz-estgoss.bilivideo.com)
TMP="$ROOT/audio/.$NAME.part"
OK=""
for M in "${MIRRORS[@]}"; do
  CODE="$(curl -s -L -m 300 -o "$TMP" -w '%{http_code}' \
          -H 'Referer: https://www.bilibili.com/' -H 'User-Agent: Mozilla/5.0' "$M/$PATHQ" || true)"
  if [[ "$CODE" == "200" && -s "$TMP" ]]; then OK="$M"; break; fi
done
[[ -n "$OK" ]] || { rm -f "$TMP"; echo "   ✗ 所有镜像都失败"; exit 1; }
echo "   节点 ${OK#https://}"
ffmpeg -y -loglevel error -i "$TMP" -c copy "$AUDIO"
rm -f "$TMP"
echo "   ✓ $AUDIO"
fi

# ---- 转谱环境（可选）----
if ! "$TENV/bin/python" -c "import demucs, basic_pitch" 2>/dev/null; then
  echo
  echo "▶ 2/3 跳过转谱：还没装转谱库。"
  echo "   现在能做的：去 MuseScore / 弹琴吧 下这首的 MIDI 放进 midi/，游戏里载入 MIDI + 这个音频。"
  echo "   想自动转谱运行一次:  ./tools/安装转谱环境.sh   （约 2 GB）"
  exit 0
fi

echo "▶ 2/3 分离人声（Demucs，第一次会下模型）…"
WORK="$ROOT/tools/.work/$NAME"; mkdir -p "$WORK"
"$TENV/bin/python" -m demucs --two-stems=vocals -n htdemucs -o "$WORK" "$AUDIO" >/dev/null
VOC="$(find "$WORK" -name vocals.wav | head -1)"
[[ -f "$VOC" ]] || { echo "   ✗ 分离失败"; exit 1; }

echo "▶ 3/3 人声转旋律 MIDI（basic-pitch）…"
"$TENV/bin/python" - "$VOC" "$ROOT/midi/$NAME.mid" <<'PY'
import sys, statistics
from basic_pitch.inference import predict
from basic_pitch import ICASSP_2022_MODEL_PATH
import pretty_midi
voc, out = sys.argv[1], sys.argv[2]
# 人声是单旋律：阈值高一点、最短音长长一点，少出碎音
_, midi, _ = predict(voc, ICASSP_2022_MODEL_PATH,
                     onset_threshold=0.6, frame_threshold=0.4,
                     minimum_note_length=120, minimum_frequency=110, maximum_frequency=1400,
                     melodia_trick=True)
notes = sorted((n for inst in midi.instruments for n in inst.notes), key=lambda n: n.start)
raw = len(notes)

# 1) 同一时刻只留最高音 → 单声部
keep = []
for n in notes:
    if keep and n.start - keep[-1].start < 0.06:
        if n.pitch > keep[-1].pitch: keep[-1] = n
        continue
    keep.append(n)

# 2) 太弱的音多半是伴奏漏过来的
keep = [n for n in keep if n.velocity >= 30]

# 3) 八度纠错：和前后 16 个音的中位数差超过 8 个半音，就是泛音/低频误判，折回去
ps = [n.pitch for n in keep]
for i, n in enumerate(keep):
    med = statistics.median(ps[max(0, i - 8): i + 9])
    while n.pitch - med > 8:  n.pitch -= 12
    while med - n.pitch > 8:  n.pitch += 12

# 4) 两边都空 1 秒以上的孤立短音是杂音
clean = []
for i, n in enumerate(keep):
    prev_gap = n.start - keep[i - 1].end if i else 9
    next_gap = keep[i + 1].start - n.end if i + 1 < len(keep) else 9
    if n.end - n.start < 0.15 and prev_gap > 1.0 and next_gap > 1.0: continue
    clean.append(n)

pm = pretty_midi.PrettyMIDI(initial_tempo=120)
ins = pretty_midi.Instrument(program=0); ins.notes = clean
pm.instruments.append(ins); pm.write(out)
pitches = sorted(set(n.pitch for n in clean))
print(f"   ✓ {out}  （识别 {raw} → 清洗后 {len(clean)} 个音，{len(pitches)} 个不同音高）")
PY
rm -rf "$WORK"            # 分离出来的 wav 几百 MB，用完就删
echo
echo "完成。游戏里：载入 MIDI → midi/$NAME.mid ；载入音频 → audio/$NAME.m4a ；对齐滑块保持 0。"
