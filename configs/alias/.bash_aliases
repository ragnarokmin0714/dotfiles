#[ -f ~/.alias/.bash_env ] && source ~/.alias/.bash_env
#[ -f ~/.alias/.bash_git ] && source ~/.alias/.bash_git
[ -f /etc/profile.d/.alias/.bash_env ] && source /etc/profile.d/.alias/.bash_env
[ -f /etc/profile.d/.alias/.bash_git ] && source /etc/profile.d/.alias/.bash_git
[ -f /etc/profile.d/.alias/.bash_functions ] && source /etc/profile.d/.alias/.bash_functions
[ -f /etc/profile.d/.alias/.bash_pkg ] && source /etc/profile.d/.alias/.bash_pkg
[ -f /etc/profile.d/.alias/.bash_disk ] && source /etc/profile.d/.alias/.bash_disk
[ -f /etc/profile.d/.alias/.bash_nginx ] && source /etc/profile.d/.alias/.bash_nginx
[ -f /etc/profile.d/.alias/.bash_mongo ] && source /etc/profile.d/.alias/.bash_mongo
[ -f /etc/profile.d/.alias/.bash_nvm ] && source /etc/profile.d/.alias/.bash_nvm

# Option letters across these modules: a letter keeps one meaning everywhere, so
# habits carry over between functions. Check this list before adding an option.
#   -n, --dry-run   show what would happen, change nothing  (git_clean_merged, disk_grow)
#   -y, --yes       skip the confirmation prompts           (pkg_ensure, pkg_remove, disk_grow)
#   -h, --help      print usage                             (disk_grow)
#   -p, --package   package name, takes a value             (pkg_installed, pkg_ensure, pkg_remove)
#   -m, --manager   package manager, takes a value          (pkg_installed, pkg_ensure, pkg_remove)
#   -g, --global    global install                          (pkg_installed, pkg_ensure, pkg_remove)
#   -s, --search    search instead of the exact name        (pkg_installed, pkg_ensure, pkg_remove)
# Older exceptions, kept so existing habits still work: pkg_unused -s is
# --min-size, sys_toolkit -m is --menu. Don't add new ones.

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