// https://api.slack.com/apis/connections/socket
//
// Created an app.

/*
Manifest:
```
_metadata:
  major_version: 1
  minor_version: 1
display_information:
  name: Toit
settings:
  interactivity:
    is_enabled: true
  org_deploy_enabled: false
  socket_mode_enabled: true
  token_rotation_enabled: false
```
*/

import net
import tls
import certificate_roots
import http
import reader show BufferedReader
import encoding.json
import web_socket

SLACK_HOST ::= "slack.com"
SLACK_PORT ::= 443
SLACK_CERTIFICATE ::= certificate_roots.DIGICERT_GLOBAL_ROOT_CA

TOKEN ::= "xapp-1-A02GZ5TF8NS-2577213561606-a9f4beadb1e39f018d9524564ec8bdd54e93abb3552e41b3ec676a9f1db05a59"


connect_to_slack -> tls.Socket:
  interface := net.open
  socket := interface.tcp_connect SLACK_HOST SLACK_PORT
  secure := tls.Socket.client socket
      --server_name=SLACK_HOST
      --root_certificates=[SLACK_CERTIFICATE]
  secure.handshake
  return secure


fetch_wss_url:
  secure := connect_to_slack
  connection := http.Connection secure SLACK_HOST
  request /http.Request := connection.new_request "POST" "/api/apps.connections.open"
  request.headers.add "Content-type" "application/x-www-form-urlencoded"
  request.headers.add "Authorization" "Bearer $TOKEN"

  response := request.send

  decoded := json.decode_stream response
  connection.close
  m /Map := {:}
  if decoded is not Map or
      not decoded.contains "ok" or
      not decoded["ok"] or
      not decoded.contains "url":
    throw "Unexpected response"

  return decoded["url"]

connect_wss wss_url -> web_socket.WebSocketClient:
  secure := connect_to_slack
  // TODO(florian): don't just assume that the HOST is wss-primary.slack.com
  connection := http.Connection secure "wss-primary.slack.com"
  print wss_url
  path := wss_url.trim --left "wss://wss-primary.slack.com"
  print path
  request /http.Request := connection.new_request "GET" "$path&debug_reconnects=true" // "$wss_url&debug_reconnects=true"
  request.headers.add "Authorization" "Bearer $TOKEN"
  return web_socket.WebSocketClient connection request

main:
  wss_url := fetch_wss_url
  client := connect_wss wss_url

  task::
    while msg := client.read:
      print msg


