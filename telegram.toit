// Using a local telegram-bot-api server:
//   https://github.com/tdlib/telegram-bot-api

import encoding.json
import certificate_roots
import net
import tls
import http
import reader show BufferedReader

/**
Token to allow access to the telegram service.
Use BotFather to create tokens: https://core.telegram.org/bots#6-botfather
*/
TOKEN ::= "2017095579:AAEOZExRK7Y50SlypriiNC5U9hlGVmxgaqU"
HOST ::= "api.telegram.org"
PORT ::= 443
CERTIFICATE ::= certificate_roots.GO_DADDY_ROOT_CERTIFICATE_AUTHORITY_G2

HTTPS_PROXY_HOST ::= "10.140.29.106"
HTTPS_PROXY_PORT ::= 8080

class Telegram:
  closed_ /bool := false
  last_received_update_id_ /int? := null
  token_ /string

  constructor .token_:

  listen_for_updates:
    while not closed_:
      opt := {
        "timeout" : 600,
      }
      if last_received_update_id_:
        opt["offset"] = last_received_update_id_ + 1
      response := call "getUpdates" opt
      response.do:
        last_received_update_id_ = it["update_id"]
        handle_update_ it
    // Acknowledge the last received message by requesting one more.
    call "getUpdates" {
      "offset": last_received_update_id_ + 1,
      "limit": 1,
      "timeout": 0,
    }

  handle_update_ update/Map:
    if update.contains "message":
      handle_message_ update["message"]

  handle_message_ message/Map:
    from := message["from"]
    from_id := from["id"]
    from_first := from["first_name"]
    from_last := from["last_name"]
    text := message["text"]
    channel := message["chat"]["id"]

    if text == "/stop":
      closed_ = true
      return
    if text == "/status":
      send_message --chat_id=channel "Everything is good"
      return
    print "$from_first $from_last: $text"


  get_me:
    response := call "getMe" {:}
    print "Id: $response["id"]"
    print "Is-Bot: $response["is_bot"]"
    print "Name: $response["first_name"]"

  send_message --chat_id text/string:
    return call "sendMessage" {
      "chat_id": chat_id,
      "text": text,
    }

  call method/string opt/Map -> any:
    interface := net.open
    // We are using mitmproxy to convert http into https connections outside
    // the ESP32.
    //   mitmproxy -s https-redirect.py
    socket := interface.tcp_connect HTTPS_PROXY_HOST HTTPS_PROXY_PORT
    /*
    socket := interface.tcp_connect HOST PORT
    secure := tls.Socket.client socket
        --server_name=HOST
        --root_certificates=[CERTIFICATE]
    secure.handshake
    socket = secure
    */
    connection := http.Connection socket HOST
    request /http.Request := connection.new_request "POST" "/bot$TOKEN/$method"
    request.headers.add "Content-type" "application/json"
    request.body = json.encode opt
    response := request.send
    decoded := json.decode_stream response
    connection.close
    print "decoded: $decoded"
    if not decoded["ok"]:
      throw "Error: $decoded["description"]"
    return decoded["result"]

main:
  telegram := Telegram TOKEN
  telegram.get_me
  telegram.listen_for_updates
