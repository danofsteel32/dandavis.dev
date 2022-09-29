# dandavis.dev

The source repo for my personal website.

Allow to run as non root

`sudo setcap cap_net_bind_service=+ep ./bin/caddy`

`./bin/caddy run --config caddy.json`

### Layout
```
dandavis.dev/
    top-level html pages
    bin/
    share/
    posts/
    static/
        css/
        js/
        images/
        videos/
        resume.pdf
        favicon(s)
```

- Resume (HTML or PDF?)
- civ4save
    - about, screenshots, link to repo/docs
- garage sensor project
    - sensor, raspi, quart sse
- testing quart sse endpoints
- gingr api
- dog image dataset
- building aravis on fedora
- genicam starter pack
- lift-calc
- sway-focus
    - get the currently focused window
    - mine it for context/metadata/tags
    - post to cash-eh server
