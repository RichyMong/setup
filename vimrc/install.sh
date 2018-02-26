#!/usr/bin/env bash
SCRIPT_NAME=$(readlink -f $(basename $0))
SCRIPT_DIR=${SCRIPT_NAME%/*}

if [ -f ~/.vimrc ]; then
    mkdir ~/.vimbackup
    cp ~/.vimrc ~/.vimbackup/vimrc_$(date +%y%m%d%H%M)
fi

mkdir -p ~/.vim/

git clone https://github.com/VundleVim/Vundle.vim ~/.vim/vundle/

ln -s $SCRIPT_DIR/vimrc ~/.vimrc

vim -u "~/.vimrc" "+set nomore" "+BundleInstall!" "+BundleClean" "+qall"
