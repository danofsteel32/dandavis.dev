#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail


VENVPATH="${VENVPATH:-./venv}"

# Dependency Management

venv() {
    if [[ -d "${VENVPATH}/bin" ]]; then
        echo "source ${VENVPATH}/bin/activate"
    else
        echo "source ${VENVPATH}/Scripts/activate"
    fi
}

make-venv() {
    python -m venv "${VENVPATH}"
}

reset-venv() {
    rm -rf "${VENVPATH}"
    make-venv
}

wrapped-python() {
    # unix
    if [[ -d "${VENVPATH}/bin" ]]; then
        "${VENVPATH}"/bin/python "$@"
    # windows
    elif [[ -d "${VENVPATH}/Scripts" ]]; then
        "${VENVPATH}"/Scripts/python "$@"
    else
        echo
        echo "No virtual environment"
        echo "Hint: ./run.sh install"
        echo
    fi
}

wrapped-pip() {
    wrapped-python -m pip "$@"
}

python-deps() {
    wrapped-pip install --upgrade pip setuptools wheel
    wrapped-pip install -r requirements.txt
}

npm-deps() {
    set -x
    sudo dnf install npm -y
    set +x
    npm install stylelint lessc
}

install() {
    if [[ -d "${VENVPATH}" ]]; then
        python-deps "$@"
    else
        make-venv && python-deps "$@"
    fi
    npm-deps
}



build() {
    # copy directory structure first
    find src -type d -printf "site/%P\0" | xargs -0 mkdir -p
    # build style sheet
    ./node_modules/less/bin/lessc src/css/styles.less > site/css/styles.css
    # copy css, fonts, imgs, js
    rsync -azP src/js/ site/js/
    rsync -azP src/css/*.css site/css
    rsync -azP src/fonts/ site/fonts
    wrapped-python scripts/build-html.py
}


clean() {
    rm -rf dist/
    rm -rf .eggs/
    rm -rf build/
    rm -rf site/
    find . -name '*.pyc' -exec rm -f {} +
    find . -name '*.pyo' -exec rm -f {} +
    find . -name '*~' -exec rm -f {} +
    find . -name '__pycache__' -exec rm -fr {} +
    find . -name '.mypy_cache' -exec rm -fr {} +
    find . -name '.pytest_cache' -exec rm -fr {} +
    find . -name '*.egg-info' -exec rm -fr {} +
}

lint() {
    npx stylelint **/*.less
}

help() {
    echo
    echo "./run.sh                          # serve site/ and live reload on file changes"
    echo "./run.sh build                    # get everything ready for deploying"
    echo "./run.sh install                  # install development dependencies"
    echo "./run.sh lint                     # lint html and css files"
    echo "./run.sh clean                    # rm files not source controlled"
    echo "./run.sh help                     # print this helpful message"
    echo
}

new-post() {
    ./scripts/new-post.sh "$@"
}

default() {
    build
    wrapped-python server.py 
}

TIMEFORMAT="Task completed in %3lR"
time "${@:-default}"
