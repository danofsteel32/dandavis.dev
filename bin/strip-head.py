#!/usr/bin/env python

import sys


path = sys.argv[1]

with open(path, "r") as file:
    _write = False
    for line in file:
        if _write:
            print(line.strip())
        else:
            if line == "<!-- ENDHEAD -->\n":
                _write = True
