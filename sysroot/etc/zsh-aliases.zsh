alias df=duf
alias ski="sk --ansi -c 'rg --color=always --line-number \"{}\"'"
alias ls="eza"
alias ls-partitions="lsblk"
alias ls-network="sudo ss -lntup"
alias lh="ls -trhgGN --color=always | tr -s ' ' | cut -d' ' -f4-"
alias gitdots="git --git-dir=$HOME/.local/share/dotfiles --work-tree=$HOME"
alias nix-build-env="nix-shell -I nixpkgs=/home/arne/nixpkgs -p binutils pkg-config gnumake cmake llvm llvmPackages.libclang llvmPackages.clang clang glibc libgit2 ocl-icd bzip2 libsass sqlite ncurses5 alsaLib xorg.libX11 manpages"
alias nix-shell="nix-shell -I nixpkgs=/home/arne/nixpkgs"
alias nix-zshell="nix-shell --run zsh"
alias rga-pdf='rga --rga-adapters=poppler'
alias yt-dlp="yt-dlp --compat-options filename-sanitization"
alias yt="yt-dlp --compat-options filename-sanitization --add-metadata -x -o '%(title)s.%(ext)s'"
alias yt_ag="yt-dlp --compat-options filename-sanitization --add-metadata -x -o '%(creator)s - %(title)s.%(ext)s'"
alias yt_up="yt-dlp --compat-options filename-sanitization --add-metadata -x -o '%(uploader)s - %(title)s.%(ext)s'"
alias aa="git commit -a --amend"
alias f="git checkout FETCH_HEAD --"
rga-eml() {
 rga --rga-accurate --rga-adapters=poppler,pandoc,mail "$@" ~/.thunderbird/*.default/ImapMail/posteo.de
}
alias b2='\nix-shell -k -j6 -I nixpkgs=/home/arne/nixpkgs-wt-2 -p'
alias b2s='\nix-shell -j1 -I nixpkgs=/home/arne/nixpkgs-wt-2 -p'
alias jl="jj log -T log_compact_fast --limit 10 --no-pager"
alias music="mpv --no-video --script=~/.config/mpv/scripts-disabled/ratings-based-shuffle.lua ~/Music/1sec_silence.mp3"
alias jsplit="JJ_EDITOR=gen-commit-message jj split"
alias copy="wl-copy"

ntop() {
 nd=$(pgrep nix-daemon | head -n1) && sudo parallel sh -c '
  secs=$(ps -o etimes= -p "$0");
  time=$(printf " %02dd %02dh %02dm %02ds " $((secs/(3600*24))) $((secs/3600%24)) $((secs%3600/60)) $((secs%60)));
  time="${time//00m/   }";
  time="${time//00h/   }";
  time="${time//00d/   }";
  pid=$(printf "%07d" $0);
  echo "PID $pid $time $(recursive-cpu-usage $0)" $(cat /proc/$0/environ | tr "\\0" "\\n" \
   | rg "^(name)=(.+)" - --replace "\$2" | tr "\\n" " ")' -- $(cat "/proc/$nd/task/$nd/children" \
   | tr ' ' '\n' | xargs -L 1 sh -c 'cat /proc/$0/task/*/children') \
   | sort | sed -s "s/ 00/   /g" | sed -s "s/ 0/  /g" | sed -s "s/   s/  0s/g"
}
nix-run() {
 ARGS=("$@")
 ARGS=( "${ARGS[@]/#/nixpkgs#}" )
 #echo $ARGS
 nix shell --impure ${ARGS[@]} --command zsh
}
g () { if [[ $# -gt 0 ]]; then git "$@"; else git status; fi }
pr() {
 git fetch origin pull/$1/head
 git merge --message="Merge PR $1" FETCH_HEAD
}
mrebase() {
 p=$(jj log --limit 1 --no-pager --no-graph -T change_id -r '..@ & merges()')
 jj new --no-edit -B @ -A $p -A @- -m 'Merge own PR'
 jj rebase -s $1 --destination master_old && jj bookmark create $2 -r $1 && jj git push --remote fork --allow-new --bookmark $2 && firefox "https://github.com/FliegendeWurst/nixpkgs/pull/new/$2"
}
mrebase3() {
 p=$(jj log --limit 1 --no-pager --no-graph -T change_id -r '..@ & merges()')
 jj new --no-edit -B @ -A $p -A @- -m 'Merge own PR'
 jj rebase -s $1 --destination master_old && jj bookmark create $2 -r $3 && jj git push --remote fork --allow-new --bookmark $2 && firefox "https://github.com/FliegendeWurst/nixpkgs/pull/new/$2"
}
ryantm() {
 git fetch r-ryantm $1
 git checkout r-ryantm/$1
 git switch -c $1
}
delta_date() {
 sudo sh -c "date --set='+$1 minutes'; sleep 0.2; date --set='-$1 minutes'"
}
build_and_push() {
 rm result 2> /dev/null
 nix build .#packages.x86_64-linux-cross-aarch64-linux.$1 && nix store sign -k ~/.local/share/nix-store-binary-cache-key-secret $(readlink -f result) && nix copy --to ssh://root@fliegendewurst.eu $(readlink -f result)
}
ch() {
 tmux capture-pane -pJ -S - -E - | rg --only-matching -r '$1' 'got:    (sha256.+)' | tail -n1 | tr -d '\n' | copy
}

###########
# WIDGETS #
###########

histdb-fzf-widget() {
  local selected num
  setopt localoptions noglobsubst noposixbuiltins pipefail 2> /dev/null
  selected=( $(_histdb_query "select DISTINCT commands.argv from commands join history on history.command_id = commands.id order by start_time desc" |
    FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS -n2..,.. --tiebreak=index --bind=ctrl-r:toggle-sort $FZF_CTRL_R_OPTS --query=${(qqq)LBUFFER} +m" fzf) )

  LBUFFER=$selected
  zle redisplay
  typeset -f zle-line-init >/dev/null && zle zle-line-init

  return $ret
}
files-fzf-widget() {
  local selected
  setopt localoptions noglobsubst noposixbuiltins pipefail 2> /dev/null
  [ -d .git ] && echo .git || git rev-parse --git-dir > /dev/null 2>&1
  if [ ! $? -eq 0 ]; then
    return
  fi
  selected=( $(git ls-files --exclude-standard | fzf --tac --preview 'bat --color=always --style=numbers --line-range=:50 {}') )
  LBUFFER=$selected
  zle redisplay
  typeset -f zle-line-init >/dev/null && zle zle-line-init
  return $ret
}
files-modified-fzf-widget() {
  local selected
  setopt localoptions noglobsubst noposixbuiltins pipefail 2> /dev/null
  [ -d .git ] && echo .git || git rev-parse --git-dir > /dev/null 2>&1
  if [ ! $? -eq 0 ]; then
    return
  fi
  selected=( $(git ls-files --modified --exclude-standard | fzf) )
  LBUFFER+=$selected
  zle redisplay
  typeset -f zle-line-init >/dev/null && zle zle-line-init
  return $ret
}

zle -N histdb-fzf-widget
zle -N files-fzf-widget
zle -N files-modified-fzf-widget
bindkey '^R' histdb-fzf-widget
bindkey '^T' files-fzf-widget
bindkey '^N' files-modified-fzf-widget

wait_until_cpu_low() {
    awk -v target="$1" '
    $12 ~ /^[0-9.]+$/ {
      current = 100 - $12
      if(current <= target) { exit(0); }
    }' < <(LC_ALL=C /nix/store/4ligq7wfpwqf96xk3g1qs9d8kiggn7s5-sysstat-12.7.4/bin/mpstat 1)
}

