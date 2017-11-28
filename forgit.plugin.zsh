wfxr::fzf() {
    fzf --border \
        --ansi \
        --cycle \
        --reverse \
        --height '80%' \
        --bind='alt-v:page-up' \
        --bind='ctrl-v:page-down' \
        --bind='alt-k:preview-up,alt-p:preview-up' \
        --bind='alt-j:preview-down,alt-n:preview-down' \
        --bind='alt-a:select-all' \
        --bind='ctrl-r:toggle-all' \
        --bind='ctrl-s:toggle-sort' \
        --bind='?:toggle-preview' \
        --preview-window="right:60%" \
        --bind='alt-w:toggle-preview-wrap' "$@"
}

# diff is fancy with diff-so-fancy!
(( $+commands[diff-so-fancy] )) && fancy='|diff-so-fancy'
(( $+commands[emojify] )) && emojify='|emojify'

unalias glo gd ga gi &>/dev/null

inside_work_tree() {
    git rev-parse --is-inside-work-tree >/dev/null
}
# git commit browser
glo() {
    inside_work_tree || return 1
    local cmd="echo {} |grep -o '[a-f0-9]\{7\}' |head -1 |xargs -I% git show --color=always % $emojify $fancy"
    eval "git log --graph --color=always --format='%C(auto)%h%d %s %C(black)%C(bold)%cr' $@ $emojify" |
        wfxr::fzf -e +s --tiebreak=index \
            --bind="enter:execute($cmd |less -R)" \
            --preview="$cmd"
}
# git diff brower
gd() {
    inside_work_tree || return 1
    local cmd="git diff --color=always -- {} $emojify $fancy"
    git ls-files --modified |
        wfxr::fzf -e -0 \
            --bind="enter:execute($cmd |less -R)" \
            --preview="$cmd"
}
# git add selector
ga() {
    inside_work_tree || return 1
    # '31m' matches red color to filter out added files which is all green
    local files=$(git -c color.status=always status --short |
        grep 31m |
        awk '{printf "[%10s]  ", $1; $1=""; print $0}' |
        wfxr::fzf -e -0 -m --nth 2..,.. \
            --preview="git diff --color=always -- {-1} $emojify $fancy" |
        cut -d] -f2 |
        sed 's/.* -> //') # for rename case
    [[ -n $files ]] && echo $files |xargs -I{} git add {} && git status
}

# git ignore generator
export giCache=~/.giCache
export giIndex=$giCache/.list
gi() {
    [ -f $giIndex ] || gi-update-index
    local preview="echo {} |awk '{print \$2}' |xargs -I% bash -c 'cat $giCache/% 2>/dev/null || (curl -sL https://www.gitignore.io/api/% |tee $giCache/%)'"
    IFS=$'\n'
    [[ $# -gt 0 ]] && args=($@) || args=($(cat $giIndex |nl -nrn -w4 -s'  ' |fzf -m --preview="$preview" --preview-window="right:70%" |awk '{print $2}'))
    gi-get ${args[@]}
}
GI() {
    inside_work_tree || return 1
    gi >> .gitignore
}
gi-update-index() {
    mkdir -p $giCache
    curl -sL https://www.gitignore.io/api/list |tr ',' '\n' > $giIndex
}
gi-get() {
    mkdir -p $giCache
    echo $@ |xargs -I{} bash -c "cat $giCache/{} 2>/dev/null || (curl -sL https://www.gitignore.io/api/{} |tee $giCache/{})"
}
gi-clean() {
    setopt localoptions rmstarsilent
    [[ -d $giCache ]] && rm -rf $giCache/*
}
