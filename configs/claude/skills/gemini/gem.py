#!/usr/bin/env python3
"""gem -- call the Gemini API for Claude: text, images, speech, and reading files.

Standard library only (Python 3.8+). The key comes from GEMINI_API_KEY, or from
~/.config/secrets/gemini.env when the variable is unset; it is sent only in the
x-goog-api-key header and never printed. See SKILL.md for when to use it.

  gem.py models [FILTER]
  gem.py text  [-m MODEL] [-f FILE]... [--fps N] PROMPT
  gem.py image [-m MODEL] [-f REF]... [-n N] -o DIR PROMPT
  gem.py tts   [-m MODEL] [-v VOICE] -o FILE.wav TEXT

PROMPT / TEXT "-" reads stdin. Every generated file gets a FILE.json beside it
(model, prompt, date) so where an asset came from is never lost.

Without -m each command tries the newest model of its kind first (MODELS) and
falls back to the next when one is busy, has no quota (free tier) or is gone.
"""
import argparse
import base64
import datetime
import json
import mimetypes
import os
import socket
import sys
import time
import urllib.error
import urllib.request
import wave

API = "https://generativelanguage.googleapis.com"
SECRETS = os.path.expanduser("~/.config/secrets/gemini.env")
# Newest first (Roger: always the newest model that works). Keep these up to
# date from `gem.py models`; the tail is what the free tier answers.
MODELS = {
    "text": ["gemini-4-argon", "gemini-3.8-flash", "gemini-3.7-flash",
             "gemini-3.6-flash", "gemini-3.5-flash"],
    "image": ["gemini-nano-banana-2.1", "gemini-3.1-flash-image", "gemini-3-pro-image"],
    "tts": ["gemini-3.8-flash-tts", "gemini-3.8-flash-lite-tts"],
}
# Inline data must keep the whole request under 20 MB; base64 adds a third.
INLINE_MAX = 14 * 1024 * 1024
# A busy model can hold the connection without answering; give up on it then
# (sooner while an older model is left to fall back on).
TIMEOUT, FALLBACK_TIMEOUT = 180, 90
# A busy model answers 503: try again this many times, this far apart (only
# when no model is left to fall back on).
RETRIES, RETRY_WAIT = 2, 8
# Models found busy are skipped for a while instead of waited on again.
BUSY_FILE = os.path.expanduser("~/.cache/gem/busy.json")
BUSY_SECS = 15 * 60


class Fail(Exception):
    def __init__(self, msg, skip=None):
        super().__init__(msg)
        # Why another model may do instead: "busy", "billing", "quota", "gone".
        self.skip = skip


def key():
    k = os.environ.get("GEMINI_API_KEY", "").strip()
    if not k and os.path.isfile(SECRETS):
        with open(SECRETS) as f:
            for line in f:
                line = line.strip()
                if line.startswith("export "):
                    line = line[len("export "):]
                name, _, value = line.partition("=")
                if name == "GEMINI_API_KEY":
                    k = value.strip().strip("'\"")
    if not k:
        raise Fail("no GEMINI_API_KEY (set it, or store it in %s)" % SECRETS)
    return k


def request(method, url, body=None, headers=None, raw=False,
            retries=RETRIES, timeout=TIMEOUT):
    """One API call; JSON in and out unless `raw` (then bytes in, response out)."""
    h = {"x-goog-api-key": key()}
    h.update(headers or {})
    data = body
    if body is not None and not raw:
        data = json.dumps(body).encode()
        h["content-type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    for attempt in range(retries + 1):
        try:
            resp = urllib.request.urlopen(req, timeout=timeout)
            break
        except urllib.error.HTTPError as e:
            if e.code == 503 and attempt < retries:
                sys.stderr.write("gem: model busy (503), retrying in %ds\n" % RETRY_WAIT)
                time.sleep(RETRY_WAIT)
                continue
            msg = explain(e)
            skip = {503: "busy", 404: "gone"}.get(e.code)
            if e.code == 429:
                skip = "billing" if "needs billing" in msg else "quota"
            raise Fail(msg, skip) from None
        except urllib.error.URLError as e:
            if isinstance(e.reason, socket.timeout):
                raise Fail("no answer in %ds (model busy?)" % timeout, "busy") from None
            raise Fail("network: %s" % e.reason) from None
        except socket.timeout:  # TimeoutError from 3.10 on
            raise Fail("no answer in %ds (model busy?)" % timeout, "busy") from None
    if raw:
        return resp
    with resp:
        text = resp.read()
    return json.loads(text) if text else {}


def explain(e):
    """An API error in one or a few lines: status, message, which quota."""
    try:
        err = json.load(e).get("error", {})
    except ValueError:
        return "HTTP %d" % e.code
    message = err.get("message", "")
    lines = ["HTTP %d %s: %s" % (e.code, err.get("status", ""), message.split("\n")[0])]
    for d in err.get("details", []):
        for v in d.get("violations", []):
            dims = v.get("quotaDimensions", {})
            lines.append("  quota %s (model %s)" % (v.get("quotaId"), dims.get("model", "-")))
    # A free-tier limit of 0 means the model is not on the free tier at all,
    # not that today's share is used up.
    if e.code == 429 and "FreeTier" in "".join(lines) and "limit: 0" in message:
        lines.append("  -> free tier: this model needs billing on the key's project")
    return "\n".join(lines)


def read_arg(s):
    return sys.stdin.read().rstrip("\n") if s == "-" else s


def files_upload(path, mime):
    """A large file through the Files API; returns its file resource."""
    size = os.path.getsize(path)
    resp = request("POST", API + "/upload/v1beta/files",
                   json.dumps({"file": {"display_name": os.path.basename(path)}}).encode(),
                   {"X-Goog-Upload-Protocol": "resumable",
                    "X-Goog-Upload-Command": "start",
                    "X-Goog-Upload-Header-Content-Length": str(size),
                    "X-Goog-Upload-Header-Content-Type": mime,
                    "content-type": "application/json"}, raw=True)
    with resp:
        url = resp.headers.get("x-goog-upload-url")
    if not url:
        raise Fail("upload: no upload URL returned")
    with open(path, "rb") as f:
        resp = request("POST", url, f.read(),
                       {"X-Goog-Upload-Offset": "0",
                        "X-Goog-Upload-Command": "upload, finalize"}, raw=True)
    with resp:
        file = json.load(resp)["file"]
    # Videos are processed before they can be used.
    while file.get("state") == "PROCESSING":
        time.sleep(3)
        file = request("GET", API + "/v1beta/" + file["name"])
    if file.get("state") == "FAILED":
        raise Fail("upload: Gemini could not process %s" % path)
    return file


def parts_for(paths, fps):
    """Request parts for attached files, and the uploads to delete afterwards."""
    parts, uploaded = [], []
    for p in paths:
        if not os.path.isfile(p):
            raise Fail("no such file: %s" % p)
        mime = mimetypes.guess_type(p)[0] or "application/octet-stream"
        if os.path.getsize(p) <= INLINE_MAX:
            with open(p, "rb") as f:
                part = {"inlineData": {"mimeType": mime,
                                       "data": base64.b64encode(f.read()).decode()}}
        else:
            file = files_upload(p, mime)
            uploaded.append(file["name"])
            part = {"fileData": {"mimeType": mime, "fileUri": file["uri"]}}
        if fps and mime.startswith("video/"):
            part["videoMetadata"] = {"fps": fps}
        parts.append(part)
    return parts, uploaded


def busy_models():
    try:
        with open(BUSY_FILE) as f:
            seen = json.load(f)
    except (OSError, ValueError):
        return {}
    return {m: t for m, t in seen.items() if time.time() - t < BUSY_SECS}


def mark_busy(model):
    seen = busy_models()
    seen[model] = time.time()
    try:
        os.makedirs(os.path.dirname(BUSY_FILE), exist_ok=True)
        with open(BUSY_FILE, "w") as f:
            json.dump(seen, f)
    except OSError:
        pass


def generate(models, parts, config=None):
    """Ask the first model in `models` that answers; returns (parts, model)."""
    body = {"contents": [{"parts": parts}]}
    if config:
        body["generationConfig"] = config
    busy = busy_models()
    # Recently busy ones go last rather than being dropped: they may be all there is.
    order = [m for m in models if m not in busy] + [m for m in models if m in busy]
    for i, model in enumerate(order):
        last = i == len(order) - 1
        try:
            d = request("POST", "%s/v1beta/models/%s:generateContent" % (API, model), body,
                        retries=RETRIES if last else 0,
                        timeout=TIMEOUT if last else FALLBACK_TIMEOUT)
            break
        except Fail as e:
            if e.skip == "busy":
                mark_busy(model)
            if last or not e.skip:
                raise
            sys.stderr.write("gem: %s %s, trying %s\n" % (model, {
                "busy": "is busy", "billing": "needs billing", "quota": "is out of quota",
                "gone": "is not available"}[e.skip], order[i + 1]))
    return answer(d, model), model


def answer(d, model):
    cands = d.get("candidates") or []
    if not cands:
        reason = d.get("promptFeedback", {}).get("blockReason", "no candidates")
        raise Fail("nothing generated: %s" % reason)
    u = d.get("usageMetadata", {})
    sys.stderr.write("[%s] tokens in %s, out %s\n" % (
        model, u.get("promptTokenCount", "?"), u.get("candidatesTokenCount", "?")))
    content = cands[0].get("content", {}).get("parts", [])
    if not content:
        raise Fail("nothing generated: %s" % cands[0].get("finishReason", "?"))
    return content


def provenance(path, model, prompt, extra=None):
    meta = {"model": model, "prompt": prompt,
            "made": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
            "by": "gem.py (Gemini API)"}
    meta.update(extra or {})
    with open(path + ".json", "w") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)


def cmd_models(a):
    d = request("GET", API + "/v1beta/models?pageSize=1000")
    for m in d.get("models", []):
        name = m["name"].split("/", 1)[1]
        if a.filter and a.filter not in name:
            continue
        ways = [w for w in m.get("supportedGenerationMethods", []) if w != "countTokens"]
        # * = in MODELS; a newer name without it is one to try and add.
        mark = "*" if any(name in ms for ms in MODELS.values()) else " "
        print("%s %-44s %s" % (mark, name, ",".join(ways)))


def chain(a, kind):
    """-m picks one model, no fallback; otherwise the newest of its kind first."""
    return [a.model] if a.model else MODELS[kind]


def cmd_text(a):
    parts, uploaded = parts_for(a.file, a.fps)
    try:
        out, _ = generate(chain(a, "text"), parts + [{"text": read_arg(a.prompt)}])
    finally:
        for name in uploaded:
            try:
                request("DELETE", API + "/v1beta/" + name)
            except Fail:
                pass
    print("".join(p.get("text", "") for p in out if not p.get("thought")))


def cmd_image(a):
    os.makedirs(a.out, exist_ok=True)
    prompt = read_arg(a.prompt)
    parts, _ = parts_for(a.file, None)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    for i in range(a.n):
        out, model = generate(chain(a, "image"), parts + [{"text": prompt}],
                              {"responseModalities": ["TEXT", "IMAGE"]})
        for j, p in enumerate(q for q in out if "inlineData" in q):
            mime = p["inlineData"]["mimeType"]
            ext = mimetypes.guess_extension(mime) or ".bin"
            path = os.path.join(a.out, "%s-%d-%d%s" % (stamp, i + 1, j + 1, ext))
            with open(path, "wb") as f:
                f.write(base64.b64decode(p["inlineData"]["data"]))
            provenance(path, model, prompt, {"references": a.file})
            print(path)
        note = "".join(p.get("text", "") for p in out if not p.get("thought")).strip()
        if note:
            sys.stderr.write(note + "\n")


def cmd_tts(a):
    text = read_arg(a.text)
    config = {"responseModalities": ["AUDIO"],
              "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": a.voice}}}}
    out, model = generate(chain(a, "tts"), [{"text": text}], config)
    audio = next((p["inlineData"] for p in out if "inlineData" in p), None)
    if not audio:
        raise Fail("no audio returned")
    raw = base64.b64decode(audio["data"])
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    if raw[:4] == b"RIFF":
        # Newer TTS models send a whole WAV file.
        with open(a.out, "wb") as f:
            f.write(raw)
    else:
        # Older ones send raw 16-bit mono PCM (rate in the MIME type, 24 kHz by default).
        rate = 24000
        for field in audio["mimeType"].split(";"):
            if field.strip().startswith("rate="):
                rate = int(field.split("=")[1])
        with wave.open(a.out, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(raw)
    provenance(a.out, model, text, {"voice": a.voice})
    print(a.out)


def main(argv=None):
    ap = argparse.ArgumentParser(prog="gem.py", description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("models", help="list the models this key can see")
    p.add_argument("filter", nargs="?", help="only names containing this")
    p.set_defaults(run=cmd_models)

    p = sub.add_parser("text", help="text answer; attach images, video, audio or PDFs with -f")
    p.add_argument("-m", "--model", help="this model only (default: newest that answers)")
    p.add_argument("-f", "--file", action="append", default=[], help="attach a file (repeatable)")
    p.add_argument("--fps", type=float, help="frames a second sampled from videos (default 1)")
    p.add_argument("prompt", help='the prompt, or "-" for stdin')
    p.set_defaults(run=cmd_text)

    p = sub.add_parser("image", help="generate images into a directory")
    p.add_argument("-m", "--model", help="this model only (default: newest that answers)")
    p.add_argument("-f", "--file", action="append", default=[], help="a reference image (repeatable)")
    p.add_argument("-n", type=int, default=1, help="how many requests (default 1)")
    p.add_argument("-o", "--out", required=True, help="output directory")
    p.add_argument("prompt", help='the prompt, or "-" for stdin')
    p.set_defaults(run=cmd_image)

    p = sub.add_parser("tts", help="speak text into a WAV file")
    p.add_argument("-m", "--model", help="this model only (default: newest that answers)")
    p.add_argument("-v", "--voice", default="Leda", help="prebuilt voice (default Leda)")
    p.add_argument("-o", "--out", required=True, help="output .wav")
    p.add_argument("text", help='what to say (style cues allowed), or "-" for stdin')
    p.set_defaults(run=cmd_tts)

    a = ap.parse_args(argv)
    try:
        a.run(a)
    except Fail as e:
        sys.stderr.write("gem: %s\n" % e)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
