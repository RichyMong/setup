#!/usr/bin/env bash

if ! which realpath &> /dev/null; then
    alias realpath="readlink --canonicalize"
fi

function install_apps
{
    my_apps="git vim ctags cscope cmake g++ tmux abc def"
    to_be_installed=""
    for app in $my_apps; do
        if ! which $app &> /dev/null; then
            to_be_installed="$to_be_installed $app"
        fi
    done

    dist=$(lsb_release -d | awk '{ print $2 }')
    install_cmd=
    if [[ "$dist" = *"Ubuntu"* ]]; then
        install_cmd="apt install"
    elif [[ "$dist" = *"Arch Linux"* ]]; then
        install_cmd="pacman -S"
    else
        return
    fi

    sudo $install_cmd $to_be_installed
}

function install_cfg_file
{
    for dir in $(ls); do
        if [ ! -d $dir ]; then
            continue
        fi

        if [ -f $dir/install.sh ]; then
            cd $dir && bash install.sh
            cd .. # back to the old directory
        else
            echo "Unable to install $dir configuration: no install script found"
        fi
    done
}

install_apps
install_cfg_file
