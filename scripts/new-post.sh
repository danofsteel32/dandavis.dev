#!/usr/bin/env bash

# Go from a slug to basic post template

slug="$1"
title="${slug//-/ }" # replace dashes with spaces
title=$(echo "$title" | sed -E 's/[[:alpha:]]+/\u&/g') # capitalize each word
d=$(date +"%Y-%m-%d")
read -r -d '' POST << EOM
{% extends "base.html" %}
{% block meta %}
<meta
  name="description"
  content=""
/>
<meta name="date" content="${d}"/>
<meta name="last_updated" content="${d}"/>
{% endblock %}
{% block title %}${title}{% endblock %}
{% block content %}
<main>
  <article class="wrapper flow">
    <h2>${title}</h2>
  </article>
</main>
{% endblock %}
EOM

echo "NEW POST: $title"
echo "$POST" > src/posts/"$slug".html
