#!/usr/bin/env python

import sys

path = sys.argv[1]

with open(path, "r") as file:
    for line in file:
        if line == "<!-- ENDHEAD -->\n":
            break
        print(line.strip())
