import net
import net.tcp
import tls
import writer show Writer
import reader show BufferedReader
import certificate_roots

/**
Simple example of how to connect an ESP32 to IRC.

Joins the $IRC_CHANNEL, and listens to commands.
Either write the command in the chat, or use a private message.

For example:
``` irc
/msg Toit status
```
*/

NICK ::= "Toit"

IRC_SERVER ::= "irc.libera.chat"
IRC_PORT ::= 6697
IRC_CERTIFICATE ::= certificate_roots.ISRG_ROOT_X1

/*
IRC_SERVER ::= "irc.libera.chat"
IRC_PORT ::= 6667
IRC_CERTIFICATE ::= null
*/

IRC_CHANNEL ::= "##toit-irc"

class IrcMessage:
  from /string
  to   /string
  msg  /string

  constructor .from .to .msg:

  is_public: return to.starts_with "#"
  is_ctcp: return msg.starts_with "\x01"

class Irc:
  socket_ / tcp.Socket? := null

  connect host/string port/int:
    interface := net.open
    socket := interface.tcp_connect host port
    if IRC_CERTIFICATE:
      secure := tls.Socket.client socket
          --server_name=IRC_SERVER
          --root_certificates=[IRC_CERTIFICATE]
      secure.handshake
      socket = secure
    socket_ = socket
    task::
      reader := BufferedReader socket_
      while line := reader.read_line:
        handle_server_line line
      print "closed socket"
      if socket_: close

  handle_server_line line/string:
    print "from server: $line"
    if line.starts_with "PING ":
      writeln "PONG $(line.trim --left "PING ")"
      return
    if line.contains " PRIVMSG ":
      parsed := parse_message line
      if parsed != null: handle_message parsed

  parse_message line/string -> IrcMessage?:
    // A message line (PRIVMSG) is of the following form:
    // <tags>:<nick>!<user-info> PRIVMSG <receiver> :<msg>
    colon_pos := line.index_of ":"
    if colon_pos < 0: return null
    line = line[colon_pos + 1..]
    space_pos := line.index_of " "
    if space_pos < 0: return null
    user_info := line[..space_pos]
    bang_pos := user_info.index_of "!"
    if bang_pos < 0: return null
    user := user_info[..bang_pos]
    line = line[space_pos + 1..]
    if not line.starts_with "PRIVMSG ": return null
    line = line.trim --left "PRIVMSG"
    colon_pos = line.index_of " :"
    if colon_pos < 0: return null
    receiver := line[..colon_pos].trim
    is_public := receiver.starts_with "#"
    msg := line[colon_pos + 2..]
    return IrcMessage user receiver msg

  handle_message msg/IrcMessage:
    if msg.msg == "QUIT":
      quit
      close
    else if msg.msg == "STATUS":
      send_message "Still alive"
    else if msg.is_ctcp:
      txt := msg.msg.trim --left "\x01"
      txt = txt.trim --right "\x01"
      if txt.contains "DCC SEND":
        parts := txt.split " "
        print "parts: $parts"
        filename := parts[2]
        ip_int := int.parse parts[3]
        ip := "$((ip_int >> 24) & 0xFF).$((ip_int >> 16) & 0xFF).$((ip_int >> 8) & 0xFF).$(ip_int & 0xFF)"
        port := int.parse parts[4]
        print "$parts[5] $parts[5].to_byte_array"
        size := int.parse parts[5]
        print "DCC SEND $filename $ip $port $size"
        task::
          receive_data filename ip port size
    else:
      print "$msg.from -> $msg.to$(msg.is_public ? "" : " (private)"): $msg.msg"

  receive_data filename ip port size:
    interface := net.open
    socket := interface.tcp_connect ip port
    data := #[]
    while chunk := socket.read:
      data += chunk
    print "received $(data.size) bytes"

  /**
  Sends a message to the default channel.
  Most IRC servers require the client to have joined the channel.
  */
  send_message msg/string:
    writeln "PRIVMSG $IRC_CHANNEL :$msg"

  authenticate nick/string=NICK:
    writeln "NICK $nick"
    writeln "USER username 8 * :$nick"

  quit:
    writeln "QUIT"

  write msg:
    (Writer socket_).write msg

  writeln msg:
    write "$msg\r\n"

  close:
    socket := socket_
    socket_ = null
    socket.close

main:
  irc := Irc
  irc.connect IRC_SERVER IRC_PORT
  irc.authenticate
  print "Joining channel"
  irc.writeln "JOIN $IRC_CHANNEL"
  print "Saying hi"
  irc.send_message "Hello world"
  // Not quitting, as we are waiting for commands.
  //  irc.quit
  //  irc.close
