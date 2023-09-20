from livereload import Server, shell

server = Server()

lessc = "node_modules/less/bin/lessc"
python = "venv/bin/python"

server.watch(
    "src/css/styles.less",
    shell(f"{lessc} src/css/styles.less", output="site/css/styles.css"),
)
server.watch("src/*.html", shell(f"{python} scripts/build-html.py --full-rebuild"))
server.watch(
    "src/posts/*.html", shell(f"{python} scripts/build-html.py --full-rebuild")
)
server.serve(root="site", open_url_delay=1)
