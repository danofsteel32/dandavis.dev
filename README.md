# dandavis.dev

The source repo for my personal website.

Allow to run as non root

`sudo setcap cap_net_bind_service=+ep ./bin/caddy`

`./bin/caddy run --config CaddyFile`

### TODO
- quart, htmx, sse do a smaller demo
- explain run.sh post
- pyboilerplate.sh post
- review dogs post
- review vps post
- industrial machine vision post
- deploy script
- actually deploy it (factor in garage quart app)
- change garage quart app to use blueprint
- resume
- sed -e 's/"\\"/g' to escape all quotes in templates
