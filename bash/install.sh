#!/usr/bin/env bash

SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
date_suffix=$(date '+%Y_%m_%d_%H_%M_%S')

function install_all {
    for rcfile in $(ls); do
        if [ $rcfile == "$SCRIPT_NAME" ]; then
            continue
        fi

        echo "Installing $rcfile..."
        dest=~/.$rcfile
        if [ -f $dest ]; then
            if [ -L $dest ]; then
                unlink $dest
            else
                # backup the current resource file since we don't want to be hated.
                echo "$dest already exists. Backup it as ${dest}_${date_suffix}"
                mv $dest ${dest}_${date_suffix}
            fi
        elif [[ $rcfile == bash* ]]; then
            # double quoted to avoid tilde expansion
            update_bashrc "~/.$rcfile"
        fi

        ln -s ${PWD}/${rcfile} $dest
    done
    update_profile
}

function set_env {
    git_dir=$(realpath $PWD/../..)
    if [ "${git_dir##*/}" == "mine" ]; then
        echo "export MYGIT_DIR=${git_dir%/*}" >> ~/.bashrc
        echo "export MINE_DIR=$MYGIT_DIR/mine/" >> ~/.bashrc
        echo "export STD_DIR=$MYGIT_DIR/mine/std/" >> ~/.bashrc
    else
        echo "export MYGIT_DIR=${git_dir%/*}" >> ~/.bashrc
        echo "export STD_DIR=$MYGIT_DIR/std/" >> ~/.bashrc
    fi
}

function update_profile {
if [ ! -f ~/.bash_profile ]; then
cat >> ~/.bash_profile <<- TEXT
	if [ -f ~/.bashrc ]; then
	    . ~/.bashrc
	fi
TEXT
fi

if [ -n "$(grep "tmux" ~/.bashrc)" ]; then
    return
fi
# don't know how to tell here document not to expand the expressions, so have
# to use sed instead.
sed -i '$a \
\
# only execute this for a pseudo device so we will not block a gui-login\
# session. Besides, it do not work to put this in ~/.bash_profile which\
# is only loaded by a login shell.\
if [[ $(tty) == /dev/pts/* ]]; then\
    if which tmux >/dev/null 2>&1 && test -z ${TMUX}; then\
        session=std\
        if tmux has-session -t $session &> /dev/null; then\
            ID="`tmux ls | grep -vm1 attached | cut -d: -f1`"\
            if [ -n "${ID}" ]; then \
                tmux -2 attach -t ${ID}\
            fi\
        else \
            tmux new-session -d -n std -s "${session}" \
            tmux new-window -n code -t "${session}:1" \
            tmux new-window -n bash -t "${session}:2" \
            tmux -2 attach -t $session\
        fi \
    fi \
fi' ~/.bashrc
}

function update_bashrc {
# If the redirection operator is <<-, then all leading tab characters are
# stripped from input lines and the line containing delimiter. This allows
# here-documents within shell scripts to be indented in a natural fashion.
cat >> ~/.bashrc <<- TEXT

	if [ -f $1 ]; then
	    . $1
	fi
TEXT
}

function set_terminal_scheme {
    pushd .
    cd ~/git && git clone git://github.com/sigurdga/gnome-terminal-colors-solarized.git
    cd gnome-terminal-colors-solarized && ./set_dark.sh
    popd
}

function set_dircolor {
    pushd .

    mkdir -p ~/git
    cd ~/git && git clone https://github.com/RichyMong/dircolors-solarized >& /dev/null
    if [ $? -ne 0 ]; then
        echo "Failed to clone dircolors-solarized"
    fi

    if [ -d ~/git/dircolors-solarized ]; then
        mkdir -p ~/.dircolors
        ln -sf $PWD/dircolors-solarized/dircolors.256dark ~/.dircolors/dircolors.256dark
    fi

    popd 

# cat >> ~/.bashrc <<- TEXT

sed -i '$a \
if [ -f ~/.dircolors/dircolors.256dark ]; then\
    eval $(dircolors -b ~/.dircolors/dircolors.256dark)\
fi' ~/.bashrc

# TEXT
}

set_env
set_terminal_scheme
set_dircolor
install_all
