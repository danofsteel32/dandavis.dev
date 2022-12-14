# Quart, HTMX, and Server Sent Events

In this tutorial we are going to build a barebones realtime chat app using
the python web framework [Quart](href=https://pgjones.gitlab.io/quart) and
[Server Sent Events (SSE)](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events)
with [htmx](https://htmx.org). I quite like the htmx/SSE combo as it greatly
simplifies creating dynamically updating webpages for people who try to avoid
[npm](https://www.npmjs.com/) at all costs like myself.

<video width=640 height=200 controls>
  <source src=../static/videos/sse-demo.webm type='video/webm'>
</video>

This tutorial assumes you have Python 3.7+ along with the pip, setuptools,
venv, and wheel packages installed:
<pre><code class=language-shell>
$ python3 -m pip install --upgrade pip setuptools venv wheel
</code></pre>

Here's what the project repo will look like when we're finished:
<pre><code class=language-shell>
$ tree quart-sse-demo
.
├── pyproject.toml
└── src
    └── quart_sse_demo
        ├── __init__.py
        ├── clients.py
        ├── server.py
        ├── static
        │   └── htmx
        │       ├── ext
        │       │   ├── json-enc.js
        │       │   └── sse.js
        │       └── htmx.js
        └── templates
            ├── base.html
            ├── message_partial.jinja
            └── status_partial.jinja
</code></pre>

This shell script will create the basic structure for you if you don't want to
do it manually:
```
#!/usr/bin/env bash

mkdir -p quart-sse-demo/src/quart_sse_demo/{templates,static}
touch quart-sse-demo/src/quart_sse_demo/__init__.py
```

A basic `pyproject.toml` defining our dependencies:
```
[build-system]
requires = [
  "setuptools>=61.0.0",
  "wheel"
]
build-backend = "setuptools.build_meta"

[project]
name = "quart-sse-demo"
version = "0.1.0"
description = ""
readme = "README.md"
dependencies = [
  "quart",
]
requires-python = ">=3.7"
```

Create a virtual environment to work in and install our package and dependencies:
<pre><code class=language-shell>
$ python3 -m venv venv && ./venv/bin/python3 -m pip install -e .
</code></pre>

Now onto some actual code starting with `clients.py`. First we will create some
helper classes for managing connected clients. You would use something
like Redis in a production system but this keeps it simple and python only.
The `ConnectedClients` class is a dict-like container that allows us
to access clients by username and ensures that status updates and messages
are put into every clients message queue:
```python
# clients.py

import asyncio
from dataclasses import dataclass, field
from typing import Dict, Optional

QUEUE_SIZE = 50


def _get_queue():
  return asyncio.Queue(QUEUE_SIZE)


@dataclass
class ChatClient:
  username: str
  status: str = "Online"
  queue: asyncio.Queue = field(default_factory=_get_queue)


class ConnectedClients:
  _clients: Dict[str, ChatClient] = {}

  def __setitem__(self, username: str, client: ChatClient):
      self._clients[username] = client

  def __getitem__(self, username: str) -> Optional[ChatClient]:
      try:
          return self._clients[username]
      except KeyError:
          return None

  def __delitem__(self, username: str):
      try:
          del self._clients[username]
      except KeyError:
          pass

  def __iter__(self):
      for username in self._clients:
          yield self._clients[username]

  async def update_status(self, username: str, status: str) -> bool:
      """Returns whether or not status successfully updated."""
      try:
          self._clients[username].status = status
      except KeyError:
          print(self._clients)
          return False
      status_update = {"type": "status_update", "sender": username, "content": status}
      for client in self._clients:
          if self._clients[client].username == username:
              continue
          await self._clients[client].queue.put(status_update)
      return True

  async def new_message(self, username: str, message: str) -> bool:
      """Returns whether or not message successfully went through."""
      try:
          self._clients[username]
      except KeyError:
          return False

      _message = {"type": "message", "sender": username, "content": message}
      for client in self._clients:
          await self._clients[client].queue.put(_message)
      return True
```

Then in `server.py` we define our endpoints and logic for broadcasting status
updates and messages:
```python
# server.py

import asyncio
from dataclasses import dataclass
from typing import Dict, Optional

from quart import Quart, abort, jsonify, make_response, render_template, request
from quart.helpers import stream_with_context

from .clients import ChatClient, ConnectedClients

app = Quart(__name__)
app.clients = ConnectedClients()


@dataclass
class ServerSentEvent:
  """Helper class for formatting SSE messages."""

  data: str
  event: Optional[str] = None
  id: Optional[int] = None
  retry: Optional[int] = None

  def encode(self) -> bytes:
      # remove newlines in case data is a rendered template
      self.data = self.data.replace("\n", "")
      message = f"data: {self.data}"
      if self.event is not None:
          message = f"{message}\nevent: {self.event}"
      if self.id is not None:
          message = f"{message}\nid: {self.id}"
      if self.retry is not None:
          message = f"{message}\nretry: {self.retry}"
      message = f"{message}\r\n\r\n"
      return message.encode("utf-8")


async def get_event(data: Dict) -> ServerSentEvent:
  """Returns the correct ServerSentEvent based on data['type']."""
  if data["type"] == "status_update":
      status, username = data["content"], data["sender"]
      html = await render_template(
          "status_partial.jinja", status=status, username=username
      )
      event = ServerSentEvent(html, event="status_update")
  elif data["type"] == "message":
      message, sender = data["content"], data["sender"]
      html = await render_template(
          "message_partial.jinja", message=message, sender=sender
      )
      event = ServerSentEvent(html, event="new_message")
  return event


@app.route("/<username>", methods=["GET"])
async def index(username: str):
  return await render_template(
      "base.html",
      username=username,
      clients=app.clients,
      status="Online",
  )


@app.route("/<username>/status", methods=["PUT"])
async def update_status(username: str):
  """Endpoint clients send status updates to."""
  data = await request.get_json()
  updated = await app.clients.update_status(username, data["status"])
  if updated:
      return f'Chatting as {username}, Status: {data["status"]}'
  return jsonify(updated)


@app.route("/<username>/message", methods=["PUT"])
async def message(username: str):
  """Endpoint clients send messages to."""
  data = await request.get_json()
  sent = await app.clients.new_message(username, data["message"])
  return jsonify(sent)


@app.route("/sse")
async def sse():
  """Each client will open a connection to /sse and then listen for events."""

  if "text/event-stream" not in request.accept_mimetypes:
      abort(400)

  username = request.args.get("username", None)
  if not username:
      abort(400)

  app.clients[username] = ChatClient(username)
  await app.clients.update_status(username, "Online")
  app.logger.info(f"Add client {username}")

  # decorator needed to call render_template()
  @stream_with_context
  async def send_events():
      while True:
          try:
              # Give control back to event loop if nothing in queue
              data = await app.clients[username].queue.get()
              event = await get_event(data)
              yield event.encode()
          except asyncio.CancelledError:
              app.logger.info("Removing Client")
              del app.clients[username]
              break
          except RuntimeError:
              print("HERE")
              continue

  headers = {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Transfer-Encoding": "chunked",
  }
  response = await make_response(send_events(), headers)
  # Allow the connection to stay open indefinitely
  response.timeout = None
  return response
```

Next we need to create our Jinja templates:
```html
{# base.html #}
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SSE Demo</title>
</head>
<body>

<div hx-ext="sse" sse-connect="{{ url_for('sse', username=username) }}">
  <strong>Connected Clients</strong>
  <ul sse-swap="status_update">
  {% for client in clients %}
  {% if client.username != username %}
    <li id="status-{{ username }}">{{ client.username }}: {{ client.status }}</li>
  {% endif %}
  {% endfor %}
  </ul>

  <strong>Messages</strong>
  <ul sse-swap="new_message" hx-swap="beforeend">
  </ul>
  <form hx-put="{{ url_for('message', username=username) }}"
        hx-ext='json-enc'
        hx-swap='none'>
    <input type="text" name="message">
  </form>
</div>

<p id="status">Chatting as {{ username }}, Status: {{ status }}</p>
<form hx-put="{{ url_for('update_status', username=username) }}"
      hx-ext='json-enc'
      hx-target="#status"
      hx-swap="innerHTML"
      hx-include="this"
      hx-trigger="change">
  <input type="radio" name="status" value="Online" checked>Online
  <input type="radio" name="status" value="Away">Away
  <input type="radio" name="status" value="Offline">Offline
</form>

<script src="{{ url_for('static', filename='htmx/htmx.js') }}"></script>
<script src="{{ url_for('static', filename='htmx/ext/json-enc.js') }}"></script>
<script src="{{ url_for('static', filename='htmx/ext/sse.js') }}"></script>

</body>
</html>
```

These template fragments are so simple that they could just be format strings
but the idea is to show how you can use them with htmx.

```html
{# status_partial.html #}
<li id="status-{{ username }}">{{ username }}: {{ status }}</li>
```

```html
{# message_partial.html #}
<li>{{ sender }}: {{ message }}</li>
```

I wrote this helpful script to download the latest version of htmx and extensions
we will be using:
```bash
#!/usr/bin/env bash

htmx_version="1.8.0"  # latest as of 2022-09
htmx_extensions=("sse" "json-enc")  # add more extensions if desired

mkdir -p htmx/ext
wget -P htmx/ "https://unpkg.com/htmx.org@${htmx_version}/dist/htmx.js"

for ext in "${htmx_extensions[@]}"; do
  wget -P htmx/ext/ "https://unpkg.com/htmx.org@${htmx_version}/dist/ext/${ext}.js"
done;
```

The `json-enc` extension encodes request parameters as JSON instead
of the traditional url format. Move htmx to the `static` directory once
it's finished downloading:
<pre><code class=language-shell>
$ mv htmx src/quart_sse_demo/static
</code></pre>

Now run the quart development server with:
<pre><code class=language-shell>
$ QUART_APP=quart_sse_demo.server:app ./venv/bin/python -m quart --debug run --host 0.0.0.0 --port 8081
</code></pre>

And open 2 browser tabs for our demo users [Alice](http://localhost:8081/Alice)
and [Bob](http://localhost:8081/Bob).
