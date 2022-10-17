#!/usr/bin/env bash

out=./scripts/
local_bin="${HOME}/.local/bin"
include=(
    "record-webcam.sh"
    "get-htmx.sh"
    "unsurroundify-videos.sh"
    "mkpassword.sh"
    "resize-images.sh"
    "pyboilerplate.sh"
    "find-ip.py"
    "vm_create.sh"
)

for s in "${include[@]}"; do
    cp "${local_bin}/${s}" "${out}"
done
