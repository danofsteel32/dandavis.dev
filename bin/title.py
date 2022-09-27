#!/usr/bin/env python

import sys


path = sys.argv[1]
filename = path.split("/")[1].split(".")[0]
words = filename.split("-")

out = []
for word in words:
    if word == word.upper():
        out.append(word)
    else:
        out.append(word.title())

print(" ".join(out))
