#!/usr/bin/env bash
#===============================================================================
#   Author: Wenxuan
#    Email: wenxuangm@gmail.com
#  Created: 2018-04-06 12:12
#===============================================================================
get_fzf_options() {
    local fzf_options
    local fzf_default_options='-d 35% -m -0 --no-preview --no-border'
    fzf_options="$(tmux show -gqv '@fzf-url-fzf-options')"
    [ -n "$fzf_options" ] && echo "$fzf_options" || echo "$fzf_default_options"
}

fzf_filter() {
  eval "fzf-tmux $(get_fzf_options)"
}

open_url() {
    if hash xdg-open &>/dev/null; then
        nohup xdg-open "$@"
    elif hash open &>/dev/null; then
        nohup open "$@"
    elif [[ -n $BROWSER ]]; then
        nohup "$BROWSER" "$@"
    fi
}

get_jira_key() {
    local jira_key
    jira_key="$(tmux show -gqv '@fzf-url-jira-key')"
    if [[ -n "$jira_key" ]]; then
        echo "$jira_key"
    fi
}

get_jira_key_matcher() {
    local jira_key
    jira_key=$(get_jira_key)
    if [[ -n "$jira_key" ]]; then
        printf '(%s-[0-9]{1,})' "$jira_key"
    fi
}

open_jira() {
    if hash jira &>/dev/null; then
        jira browse "$@"
    else
        tmux display -d 2000 "tmux-fzf-url: No \`jira\` cli tool in path"
    fi
}

copy() {
    local os
    os=$(uname)
    if [[ "$os" == Darwin ]]; then
        echo -n "$@" |pbcopy
    elif [[ "$os" == Linux ]]; then
        echo -n "$@" |xclip -selection clipboard
    else
        tmux display -d 2000 "tmux-fzf-url: Unable to determine OS to set clipboard copy command"
    fi
}


limit='screen'
[[ $# -ge 2 ]] && limit=$2

if [[ $limit == 'screen' ]]; then
    content="$(tmux capture-pane -J -p)"
else
    content="$(tmux capture-pane -J -p -S -"$limit")"
fi

urls=$(echo "$content" |grep -oE '(https?|ftp|file):/?//[-A-Za-z0-9+&@#/%?=~_|!:,.;]*[-A-Za-z0-9+&@#/%=~_|]')
wwws=$(echo "$content" |grep -oE '(http?s://)?www\.[a-zA-Z](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}(/\S+)*' | grep -vE '^https?://' |sed 's/^\(.*\)$/http:\/\/\1/')
ips=$(echo "$content" |grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:[0-9]{1,5})?(/\S+)*' |sed 's/^\(.*\)$/http:\/\/\1/')
gits=$(echo "$content" |grep -oE '(ssh://)?git@\S*' | sed 's/:/\//g' | sed 's/^\(ssh\/\/\/\)\{0,1\}git@\(.*\)$/https:\/\/\2/')
gh=$(echo "$content" |grep -oE "['\"]([A-Za-z0-9-]*/[.A-Za-z0-9-]*)['\"]" | sed "s/'\|\"//g" | sed 's#.#https://github.com/&#')
jiras=$(echo "$content" |grep -oE "$(printf '(%s)' "$(get_jira_key_matcher)")")


if [[ $# -ge 1 && "$1" != '' ]]; then
    extras=$(echo "$content" |eval "$1")
fi

items=$(printf '%s\n' "${urls[@]}" "${wwws[@]}" "${gh[@]}" "${ips[@]}" "${gits[@]}" "${jiras[@]}" "${extras[@]}" |
    grep -v '^$' |
    sort -u |
    nl -w3 -s '  '
)
[ -z "$items" ] && tmux display 'tmux-fzf-url: no URLs found' && exit

fzf_filter <<< "$items" | awk '{print $2}' | \
    while read -r chosen; do
        if [[ "$chosen" == $(get_jira_key)* ]]; then
            open_jira "$chosen" &>"/tmp/tmux-$(id -u)-fzf-url.log"
        else
            open_url "$chosen" &>"/tmp/tmux-$(id -u)-fzf-url.log"
        fi
        if [[ -n "$(tmux show -gqv '@fzf-url-copy')" ]]; then
            copy "$chosen"
        fi
    done
