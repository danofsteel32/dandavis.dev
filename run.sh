#!/usr/bin/env bash

clean() {
    find . -name '*.html' -exec rm -f {} +
    rm -f ./scripts/*
    rm -f ./static/resume.pdf
}

deploy() {
    # Have to run another script on dandavis.dev to move to /var/www/public,
    # fix permissions, and restart Caddy.
    rsync -azP --cvs-exclude \
        --exclude='.mypy_cache/' \
        --exclude='run.sh' \
        --exclude='.gitignore' \
        . dandavis.dev:/home/dan/www
}

default() {
    ./bin/mkws https://dandavis.dev &&
    caddy run --config Caddyfile.dev
}

"${@:-default}"
