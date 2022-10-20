# run.sh for Python Projects

[This](href=https://www.oilshell.org/blog/2020/02/good_parts-sketch.html) page
explains the benefits of using shell scripts better than I ever could. The script
below is the base I use for all of my python projects. I even wrote
another [shell script](../scripts/pyboilerplate.sh) I call `pyboilerplate.sh`
that creates a new project directory containing this script, pyproject.toml,
setup.py, src/ and test/ directories, README, license file, etc.
I have tried using makefiles, [poetry](https://python_poetry.org),
[invoke](https://www.pyinvoke.org/), and probably a few others I'm forgetting.
But for me nothing is as flexible and easy to understand as the humble shell script.

```bash
#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

VENVPATH="./venv"

venv() {
    # print out source command for Linux and Windows
    if [[ -d "${VENVPATH}/bin" ]]; then
        echo "source ${VENVPATH}/bin/activate"
    else
        echo "source ${VENVPATH}/Scripts/activate"
    fi
}

reset_venv() {
    rm -rf "${VENVPATH}"
    make_venv
}

wrapped_python() {
    # Use the virtual environments python on Linux and Windows
    if [[ -d "${VENVPATH}/bin" ]]; then
        "${VENVPATH}"/bin/python "$@"
    else
        "${VENVPATH}"/Scripts/python "$@"
    fi
}

wrapped_pip() {
    wrapped_python -m pip "$@"
}

python_deps() {
    # Make venv if needed and install core plus any optional deps
    wrapped_pip install --upgrade pip setuptools wheel
  
    local pip_extras="${1:-}"
    if [[ -z "${pip_extras}" ]]; then
        wrapped_pip install -e .
    else
        wrapped_pip install -e ".[${pip_extras}]"
    fi
}

install() {
    if [[ -d "${VENVPATH}" ]]; then
        python_deps "$@"
    else
        make_venv && python_deps "$@"
    fi
}

build() {
    python -m build
}

publish() {
    # Using `&&` ensures that lint and tests have to pass before upload
    lint && tests && clean && build
    python -m twine upload dist/*
}

clean() {
    # Does the basics and recursively finds and deletes all pycache files
    rm -rf dist/
    rm -rf .eggs/
    rm -rf build/
    find . -name '*.pyc' -exec rm -f {} +
    find . -name '*.pyo' -exec rm -f {} +
    find . -name '*~' -exec rm -f {} +
    find . -name '__pycache__' -exec rm -fr {} +
    find . -name '.mypy_cache' -exec rm -fr {} +
    find . -name '.pytest_cache' -exec rm -fr {} +
    find . -name '*.egg-info' -exec rm -fr {} +
}

lint() {
    wrapped_python -m flake8 src/ &&
    wrapped_python -m mypy src/
}

tests() {
    wrapped_python -m pytest tests/
}

default() {
    wrapped_python
}

"${@:-default}"
```

The `${@:-default}` line at the end of the file allows me to call any function in the
script by passing the function name as an argument or fallback to the calling the
`default` function if no argument is provided. So `./run.sh lint` will run the `lint`
function and `./run.sh` will run the `default` function.

Depending on whether I'm working on a library, cli program, or webapp I will edit
`default` accordingly.

```bash
default() {
  # package/library
  wrapped_python -i -c 'import pkgname'
  # commandline tool
  wrapped_python -m pkgname.cli:run "$@"
  # dev web server
  QUART_APP=pkgname.server:app wrapped_python -m quart --debug run --reload --host 0.0.0.0 --port 8081
}
```

The `install` function creates a virtualenv if needed and installs the package
in editable mode and all dependencies as defined in a `pyproject.toml`,
`setup.cfg`, or `setup.py` file. You can also pass an optional dependency identifier
to `install`. For example `./run.sh install dev` would install all of the `dev`
dependencies listed in the `pyproject.toml` file below:

```
# pyproject.toml
[project.optional-dependencies]
dev = ["black", "flake8", "flake8-isort", "mypy", "pytest"]
```

`./run.sh build` will build both wheel and source distributions for your package
using [setuptools](https://setuptools.pypa.io/en/latest/build_meta.html) as long
as you have at least a minimal `pyproject.toml` file:

```
# pyproject.toml
[build-system]
requires = [
  "setuptools>=61.0.0",
  "wheel"
]
build-backend = "setuptools.build_meta"
```
