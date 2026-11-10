#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
asr_to_srt.py — 把音频离线转写成 SRT，供「阿B听书·改」的文稿同步使用（D 方案）。

零成本说明
----------
* 全程本地跑：不调用任何付费 API、不上传音频、不需要服务器、不需要 B 站接口。
* 唯一成本是本机 CPU 时间。30 分钟音频：small 模型约 5~15 分钟，
  medium 约 20~60 分钟；有 NVIDIA 显卡加 --device cuda 可大幅加速。
* 模型权重首次运行自动下载（small 约 460MB，medium 约 1.5GB），之后完全离线。
* faster-whisper 是 Whisper 的 CTranslate2 实现，与 whisper.cpp 同属离线 whisper 家族，
  但 pip 一条命令装好、Windows 无需编译，所以选它做默认后端。

安装（Windows PowerShell）
--------------------------
    pip install -i https://mirrors.aliyun.com/pypi/simple/ faster-whisper
    pip install -i https://mirrors.aliyun.com/pypi/simple/ yt-dlp     # 仅 --url 模式需要
    winget install Gyan.FFmpeg                                        # 或自行下载 ffmpeg 并加进 PATH

用法
----
1) 已有本地音频：
    python tool/asr_to_srt.py --audio D:\\books\\第01章.m4a --output 第01章.srt

2) 直接从 B 站链接取音频（登录才可见的内容加 --cookies-from-browser chrome）：
    python tool/asr_to_srt.py --url "https://www.bilibili.com/video/BVxxxx/?p=1" --output 第01章.srt

3) 把生成的 SRT 用记事本打开 → 全选复制 →
   手机 App 播放页「文稿」→「粘贴导入」。导一次按「本书+本章」存好，以后自动加载。

模型与精度
----------
    --model small            快，中文尚可（默认）
    --model medium           中文明显更准，慢 3~5 倍
    --model large-v3-turbo   最准，吃内存/显存
    --device cuda            有 NVIDIA 显卡时加速
    --compute float16        显卡建议配合 cuda 使用

whisper.cpp 备选（手动等价命令，本脚本不封装）
----------------------------------------------
    ffmpeg -i 第01章.m4a -ar 16000 -ac 1 -c:a pcm_s16le 16k.wav
    whisper-cli -m ggml-medium.bin -f 16k.wav -l zh --output-srt -of 第01章
    # 得到 第01章.srt

合规
----
只对你有权限使用的内容做本地转写。项目 README 的免责声明同样适用：
仅供个人学习、研究与试听交流，请勿下载、录制或传播相关内容，请勿用于商业用途。
"""

import argparse
import os
import shutil
import subprocess
import tempfile

MIRROR = "https://mirrors.aliyun.com/pypi/simple/"


def srt_ts(sec):
    """秒 -> SRT 时间戳 HH:MM:SS,mmm"""
    if sec < 0:
        sec = 0.0
    whole = int(sec)
    h = whole // 3600
    m = (whole % 3600) // 60
    s = whole % 60
    ms = int(round((sec - whole) * 1000))
    if ms >= 1000:
        s += 1
        ms = 0
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def run(cmd, quiet=False):
    print("  >", " ".join(str(c) for c in cmd))
    kw = {}
    if quiet:
        kw["stdout"] = subprocess.DEVNULL
        kw["stderr"] = subprocess.DEVNULL
    return subprocess.run(cmd, check=True, **kw)


def fetch_url(url, out_base, cookies_from_browser):
    yt = shutil.which("yt-dlp")
    if not yt:
        raise SystemExit(
            "找不到 yt-dlp。安装：pip install -i %s yt-dlp\n"
            "也可以先用你手上的下载工具拿到音频，改用 --audio。" % MIRROR
        )
    cmd = [
        yt, "-f", "bestaudio", "-x", "--audio-format", "wav",
        "--add-header", "Referer:https://www.bilibili.com",
        "--no-playlist", "-o", out_base + ".%(ext)s",
    ]
    if cookies_from_browser:
        cmd += ["--cookies-from-browser", cookies_from_browser]
    cmd.append(url)
    run(cmd)
    produced = out_base + ".wav"
    if not os.path.exists(produced):
        raise SystemExit("yt-dlp 没有产出 wav，检查链接或 Cookie（可能需要 --cookies-from-browser chrome）")
    return produced


def to_wav(src, dst):
    ff = shutil.which("ffmpeg")
    if not ff:
        raise SystemExit(
            "找不到 ffmpeg。Windows：winget install Gyan.FFmpeg，"
            "或到 https://www.gyan.dev/ffmpeg/builds/ 下载并加入 PATH。"
        )
    run([ff, "-y", "-i", src, "-ar", "16000", "-ac", "1",
         "-c:a", "pcm_s16le", dst], quiet=True)
    if not os.path.exists(dst) or os.path.getsize(dst) < 1024:
        raise SystemExit("ffmpeg 转码失败，检查音频文件是否可读。")


def transcribe(wav, model, lang, device, compute):
    try:
        from faster_whisper import WhisperModel
    except ImportError:
        raise SystemExit(
            "未安装 faster-whisper。安装：pip install -i %s faster-whisper" % MIRROR
        )
    print("加载模型 %s（device=%s, compute=%s）…" % (model, device, compute))
    engine = WhisperModel(model, device=device, compute_type=compute)
    segments, info = engine.transcribe(
        wav,
        language=lang,
        beam_size=5,
        vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 500},
    )
    print("检测语言：%s，音频时长：%.1fs" % (info.language, info.duration))
    out = []
    for seg in segments:
        text = (seg.text or "").strip()
        if not text:
            continue
        out.append((seg.start, seg.end, text))
        print("  [%s] %s" % (srt_ts(seg.start), text[:48]))
    return out


def write_srt(segments, path):
    with open(path, "w", encoding="utf-8") as f:
        n = 0
        for start, end, text in segments:
            n += 1
            f.write("%d\n%s --> %s\n%s\n\n" % (
                n, srt_ts(start), srt_ts(end), text,
            ))
    return n


def main():
    ap = argparse.ArgumentParser(
        description="离线把音频转写成 SRT（阿B听书·改 文稿同步 D 方案）"
    )
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--audio", help="本地音频文件路径")
    src.add_argument("--url", help="B 站视频链接（需 yt-dlp）")
    ap.add_argument("--output", default="out.srt", help="输出 SRT 路径")
    ap.add_argument("--model", default="small",
                    help="small / medium / large-v3-turbo，默认 small")
    ap.add_argument("--lang", default="zh", help="语言，默认 zh")
    ap.add_argument("--device", default="cpu", choices=["cpu", "cuda"])
    ap.add_argument("--compute", default="int8",
                    help="int8（CPU）/ float16（cuda 推荐）")
    ap.add_argument("--cookies-from-browser", default="",
                    help="例如 chrome / edge，用于登录才可见的内容")
    args = ap.parse_args()

    with tempfile.TemporaryDirectory(prefix="abts_asr_") as td:
        source = args.audio
        if args.url:
            source = fetch_url(args.url, os.path.join(td, "audio"),
                               args.cookies_from_browser)
        if not source or not os.path.exists(source):
            raise SystemExit("音频文件不存在：%s" % source)
        wav = os.path.join(td, "16k.wav")
        print("转 16kHz 单声道 wav…")
        to_wav(source, wav)
        print("开始离线转写（不联网、不上传）…")
        segments = transcribe(wav, args.model, args.lang,
                              args.device, args.compute)

    if not segments:
        raise SystemExit("没有识别出任何文字，试试 --model medium 或检查音频是否有人声。")
    n = write_srt(segments, args.output)
    full = os.path.abspath(args.output)
    print("\n完成：%s（%d 句）" % (full, n))
    print("下一步：记事本打开 → 全选复制 → 手机播放页「文稿」→「粘贴导入」")
    print("若文稿和声音差几秒，在面板里用 ±0.5s / ±2s 校准，偏移会自动记住。")


if __name__ == "__main__":
    main()
