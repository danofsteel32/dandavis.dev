#!/usr/bin/env bash


default() {
    ./bin/mkws https://dandavis.dev &&
    caddy run --config Caddyfile
}

"${@:-default}"
