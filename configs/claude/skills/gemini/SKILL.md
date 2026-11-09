---
name: gemini
description: Hand part of a task to Google Gemini through Roger's API key — generate reference images, voice takes (TTS) or draft text, or have Gemini watch a screen recording / read images, audio and PDFs and report back. Use when Roger asks for Gemini, for generated images or voices, or when a video needs reviewing (Claude cannot watch video itself). Claude stays in charge: Gemini makes material and second opinions, never code.
---

# gemini

`gem.py` (next to this file) calls the Gemini API with the standard library only.
Run it as `python3 ~/.claude/skills/gemini/gem.py <command> ...`.

## Who does what (Roger, 2026-11-09)

- **Claude leads.** Claude decides what to ask, writes the prompts, reviews what
  comes back, picks or rejects it, and reports to Roger.
- **Gemini makes material and second opinions only**: reference and concept
  images, voice takes, draft lines or translations, reviews of videos and
  screenshots.
- **Every line of code is Claude's.** Never copy Gemini-written code into a repo,
  not even as a starting point.
- **Apps never call Gemini at runtime.** Generated files are assets checked in or
  shipped like any other, after Roger has approved them.

## The key

- `GEMINI_API_KEY` from the environment, else `~/.config/secrets/gemini.env`
  (`export GEMINI_API_KEY=...`, mode 600). `gem.py` reads it itself: do not
  source, `cat` or echo that file, and never print the key or put it in a URL,
  a file in a repo, or the chat.
- If it is missing, give Roger these steps to run himself (the key is typed at a
  hidden prompt, never pasted into the chat):

  ```bash
  mkdir -p ~/.config/secrets && chmod 700 ~/.config/secrets
  read -rsp 'Gemini key: ' k; echo
  ( umask 077; printf 'export GEMINI_API_KEY=%s\n' "$k" > ~/.config/secrets/gemini.env )
  unset k
  ```

## Commands

```bash
gem.py models [FILTER]                       # what this key can see
gem.py text  [-m MODEL] [-f FILE]... [--fps N] PROMPT
gem.py image [-m MODEL] [-f REF]... [-n N] -o DIR PROMPT
gem.py tts   [-m MODEL] [-v VOICE] -o FILE.wav TEXT
```

- **Newest model first (Roger: always the newest that works).** Without `-m`,
  each command walks `MODELS` in `gem.py`, newest first, and falls back to the
  next when a model is busy, needs billing, is out of quota or is gone, saying
  so on stderr; the `[model]` line and the `.json` record the one that answered.
  Busy models are skipped for 15 minutes (`~/.cache/gem/busy.json`). Use `-m`
  only to pin one model on purpose: it never falls back.
- **Keep `MODELS` current.** At the start of Gemini work run `gem.py models`:
  names marked `*` are in the chains; a newer generation without the mark is to
  be tried with `-m` and, if it answers, added at the head of its chain (a
  dotfiles commit, deployed with `install.sh claude`).
- `PROMPT` / `TEXT` of `-` reads stdin (use it for long or multi-line prompts).
- `-f` attaches images, video, audio or PDFs. Files up to 14 MB go inline; larger
  ones go through the Files API and are deleted again after the answer.
- **Videos are sampled at 1 frame a second by default.** For anything brief
  (flicker, a stutter, a frame that jumps) pass `--fps` up to the recording's
  rate. Tested: a 0.2 s blink was misplaced at the default and found exactly at
  `--fps 15`. More frames cost more tokens (about 250 per frame).
- `image` and `tts` write a `FILE.json` beside each output (model, prompt, date):
  keep it with the asset, it is the record of where the asset came from.
- `tts` text may carry a style cue (`Say sleepily: ...`). Newer TTS models return
  a whole WAV, older ones raw PCM; `gem.py` handles both.

## Quotas (state on 2026-11-09)

- Free tier answers `gemini-3.8/3.7/3.6/3.5-flash` and both 3.8 TTS models.
  `gemini-4-argon`, the Pro models, every image model and Lyria have a
  free-tier limit of 0 ("needs billing"): billing must be turned on for the
  key's project (Roger's AI Pro Cloud credit). Once it is, the chains reach
  them by themselves.
- 3.8 and 3.7 Flash were often overloaded on 2026-11-09 (503, or no answer for
  minutes). A model with others behind it gets 90 s and no retries; the last
  one gets 180 s and two 503 retries.

## Where files go

1. Generate into the session's scratchpad, never straight into a repo.
2. Show Roger (paths, or a page with the images / players) and let him choose.
3. Keep what he approves under `gdrive:claude/assets/<project>/` with rclone
   (uploads ask first); add to a repo only what the project ships.

## Before anything generated ships publicly

Check Gemini's current terms on generated content and on SynthID watermarks
(every generated image carries one), and record the outcome in the project's
docs. Tell Roger the result before the asset goes into a release.
