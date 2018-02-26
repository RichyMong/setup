py3_version=3.6
download_py3_version=3.6.4

export CC=/usr/local/bin/gcc
export CXX=/usr/local/bin/g++
export LD_LIBRARY_PATH=/usr/local/lib64:$LD_LIBRARY_PATH

function _get_main_version() {
    full_version=$1
    major=${full_version%%.*}
    tmp=${full_version#*.}
    minor=${tmp%%.*}
    echo "${major}.${minor}"
}

function check_or_install_git() {
    if ! which git &> /dev/null; then
        yum install -y openssl-devel libcurl-devel expat-devel
        wget https://www.kernel.org/pub/software/scm/git/git-2.16.1.tar.gz
        old_dir=$PWD
        tar xzf git-2.16.1.tar.gz && cd git-2.16.1
        make -j8 prefix=/usr/ 
        make prefix=/usr/ install
        cd $old_dir
    fi
}

function check_or_install_cmake() {
    version=$(cmake --version 2> /dev/null)
    if [ $? -eq 0 ]; then
        version=$(echo $version | head -n 1)
        echo "Found cmake $version, requires >= 3.10"
        version=$(echo $version | sed -n "s/cmake version \([0-9.]\+\).*/\1/p")
        major=${version%%.*}
        tmp=${version#*.}
        minor=${tmp%%.*}
        if [[ "$major" -gt 3 ]] || [ "$major" -eq 3 -a "$minor" -ge 10 ]; then
            return
        fi
        path=$(which cmake)
    else
        echo "Cannot find cmake"
        major=0
        minor=0
    fi
    
    content=$(curl -s https://cmake.org/download/#latest)
    latest_version=$(echo "$content" | grep "Latest" | sed -n "s/.*Latest Release (\([0-9.]\+\).*/\1/p")
    echo "Latest release of CMake is $latest_version"
    main_version=$(_get_main_version $latest_version)
    if [ -z "$latest_version" ]; then
        latest_version=3.10.2
        main_version=3.10
    fi
    file_dir=cmake-${latest_version}
    tar_file=${file_dir}.tar.gz
    wget https://cmake.org/files/v${main_version}/${tar_file}
    if [ $? -ne 0 ]; then
        echo "Failed to download $latest_version of v$main_version"
        exit
    fi
    old_dir=$PWD
    tar xzf $tar_file && cd $file_dir && ./bootstrap && make -j8 install
    cd $old_dir
}

function check_or_install_python() {
    version=$(python3 --version 2> /dev/null)
    if [ $? -ne 0 ]; then
        echo "Cannot find python3"
        minor=0
    else
        echo "Found python $version, requires >= 3.3"
        version=$(echo $version | sed -n "s/Python \([0-9.]\+\).*/\1/p")
        tmp=${version#*.}
        minor=${tmp%%.*}
    fi
    
    if [ "$minor" -ge 3 ]; then
	    py3_version=3.$minor
        return
    fi

    old_dir=$PWD
    wget -c https://www.python.org/ftp/python/${download_py3_version}/Python-${download_py3_version}.tgz
    tar xzf Python-${download_py3_version}.tgz && cd Python-${download_py3_version}
    ./configure --prefix=/usr/local --enable-shared
    make -j8 install
    cd $old_dir
}

function check_or_install_vim() {
    vim_version=$(vim --version | head -n 1 | sed -n "s/.*Vi IMproved \([0-9.]\+\).*/\1/p")
    if [ $? -ne 0 ]; then
	echo "Cannot find vim"
        major=0
    else
	echo "Found vim $vim_version, need >= 8.0"
        major=${vim_version%%.*}
    fi
    
    if [ $major -ge 8 ]; then
        return
    fi

    yum install -y ncurses-devel
    git clone https://github.com/vim/vim
    old_dir=$PWD
    cd vim
    ./configure --enable-python3interp=dynamic\
                --with-python3-config-dir=/usr/local/lib/python${py3_version}/config-${py3_version}m-x86_64-linux-gnu/\
                --prefix=/usr/ --enable-multibyte --enable-cscope
    make -j8 prefix=/usr/ 
    make prefix=/usr/ install
    cd $old_dir
}

function check_or_install_tmux() {
    if which tmux &> /dev/null; then
        return
    fi
    git clone https://github.com/libevent/libevent
    cd libevent
	sh autogen.sh
    mkdir _build && cd _build && cmake .. && make -j8 install && cd ..
    cd ..

    git clone https://github.com/tmux/tmux.git
	cd tmux
	sh autogen.sh
	./configure
    sed -ni 's/\(LIBS *= *.*-lrt\)/\1 -lresolv/' Makefile
    make -j8 install
    cd ..
}

check_or_install_git
check_or_install_cmake
check_or_install_python
check_or_install_vim
check_or_install_tmux
