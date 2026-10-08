#!/usr/bin/env bash
# @file .bash_aliases
# @brief Shell alias entry point — sources all alias modules.
# @description
#   This is the single file sourced by ~/.bashrc (or /etc/bashrc).
#   It loads all alias/function modules in order:
#     1. .bash_env       → ANSI STYLE map, styled(), git_prompt(), build_ps1()
#     2. .bash_git       → Git aliases and interactive branch functions
#     3. .bash_functions → System, disk, and project utility functions
#
#   To add a new module, create a new file under ~/.alias/ and add a
#   source line below.
#
# SOURCED BY: ~/.bashrc via:
#   [ -f ~/.alias/.bash_aliases ] && source ~/.alias/.bash_aliases
#   PROMPT_COMMAND=build_ps1

# Determine the directory where this file lives (supports symlinks)
_ALIAS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment constants, STYLE map, and prompt builder
[ -f "$_ALIAS_DIR/.bash_env" ]       && source "$_ALIAS_DIR/.bash_env"

# Load Git aliases and interactive branch functions
[ -f "$_ALIAS_DIR/.bash_git" ]       && source "$_ALIAS_DIR/.bash_git"

# Load general system/disk/project utilities
[ -f "$_ALIAS_DIR/.bash_functions" ] && source "$_ALIAS_DIR/.bash_functions"

unset _ALIAS_DIR

# =============================================================================
# --- Quick Reference (add your own one-liners below) ---
# =============================================================================

# ~/.bashrc & source ~/.bashrc
# Documentation style: shdoc (https://github.com/reconquest/shdoc)

# --- sed Examples ---
# Delete lines 10–20 and line 24:       sed '10,20d;24d' file.txt
# Delete lines 27–143:                  sed '27,143d' file.txt

# --- Vim Examples ---
# Delete all lines:                     :%d
# Delete range:                         :10,20d
# Show line numbers:                    :set number
# Search & replace (range, confirm):    :50,100s/from/to/gc
# Search & replace (whole file):        :%s/from/to/gc
# Syntax highlighting on/off:           :syntax on / :syntax off
