# docs/refs/.alias — Read-Only Reference Snapshot

This directory contains reference copies of the `.bash_*` alias files.

**These files are NOT deployed.** The canonical source is `configs/alias/`.

## Purpose

- Serve as a human-readable reference for the original design intent
- Provide a side-by-side comparison point when reviewing changes in `configs/alias/`
- Archive early-stage drafts before the distro-compatibility rewrites

## Do not edit here expecting changes to take effect

Any updates must be made to `configs/alias/` and deployed via:

```bash
sudo bash system/aliases.sh
```

## Files

| File | Description |
|------|-------------|
| `.bash_aliases` | Entry point — sources the other three files |
| `.bash_env` | ANSI STYLE map, `styled()`, `git_prompt()`, `build_ps1()` |
| `.bash_functions` | System utility functions and aliases |
| `.bash_git` | Git aliases and interactive branch functions |
