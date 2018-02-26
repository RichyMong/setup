#!/usr/bin/env bash

mkdir -p ~/.config/cherrytree

SCRIPT_DIR=$(realpath $(dirname ${BASH_SOURCE[0]}))
ln -s $SCRIPT_DIR/cherrytree.cfg ~/.config/cherrytree/config.cfg
ln -s $SCRIPT_DIR/gitconfig ~/.gitconfig
ln -s $SCRIPT_DIR/tmux.conf ~/.tmux.conf
ln -s $SCRIPT_DIR/gdbinit ~/.gdbinit
