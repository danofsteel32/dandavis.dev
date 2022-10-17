#!/usr/bin/env python

import sys


path = sys.argv[1]
with open(path, "r") as file:
    for line in file:
        if line == "<!-- ENDHEAD -->\n":
            break
        elif "<title>" in line:
            print(line.strip().replace("<title>", "").replace("</title>", ""))
            break
    else:
        print("Untitled")
