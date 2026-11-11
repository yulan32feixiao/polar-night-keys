#!/bin/zsh
# 运行一次。装 Demucs（人声分离）+ basic-pitch（音频转 MIDI）。
# basic-pitch 的依赖不支持 Python 3.13，所以用 uv 单独拉一个 Python 3.11，不碰系统、不用 brew、不用 sudo。
set -e
cd "$(dirname "$0")"
PY=/opt/homebrew/opt/python@3.13/bin/python3.13
[[ -x "$PY" ]] || PY="$(command -v python3)"
[[ -x .env/bin/python ]] || "$PY" -m venv .env
./.env/bin/pip install --quiet --disable-pip-version-check --upgrade pip yt-dlp uv
./.env/bin/uv python install 3.11
[[ -x .tenv/bin/python ]] || ./.env/bin/uv venv --python 3.11 .tenv
echo "装转谱库（约 1 GB）…"
./.env/bin/uv pip install --python .tenv/bin/python demucs "basic-pitch[onnx]" pretty_midi "setuptools<70"
./.tenv/bin/python -c "import demucs, basic_pitch, pretty_midi; print('✓ 装好了。以后 ./B站转关卡.sh 会自动转谱。')"
