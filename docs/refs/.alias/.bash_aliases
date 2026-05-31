#[ -f ~/.alias/.bash_env ] && source ~/.alias/.bash_env
#[ -f ~/.alias/.bash_git ] && source ~/.alias/.bash_git
[ -f /etc/profile.d/.alias/.bash_env ] && source /etc/profile.d/.alias/.bash_env
[ -f /etc/profile.d/.alias/.bash_git ] && source /etc/profile.d/.alias/.bash_git
[ -f /etc/profile.d/.alias/.bash_functions ] && source /etc/profile.d/.alias/.bash_functions

# ~/.bashrc & source ~/.bashrc
# Documentation style: shdoc
# === Command Line / Vim / sed Examples ===

# --- sed Examples ---
# Delete lines 10–20 and line 24
#   `sed '10,20d;24d' file.txt`
# Delete lines 27–142 and line 143
#   `sed '27,142d;143d' file.txt`

# --- Vim Examples ---
# Delete lines:
#   `:%d`           # delete all lines
#   `:10,20d`       # delete lines 10–20
#   `:27,143d`      # delete lines 27–143
# Delete single line:
#   `:49d`          # line 49
# Line numbers:
#   `:set number`        # temporarily show
#   `:set nonumber`      # disable
#   `:set relativenumber`# show relative
# Search & replace:
#   `:50,100s/search_from/replace_to/gc`  # range, confirm each
#   `:%s/search_from/replace_to/gc`       # entire file, confirm each
#   `:s/search_from/replace_to/gc`        # current line, confirm each
# Syntax highlighting commands (Vim only):
#    - [x] :syntax on
#    - [x] :syntax off