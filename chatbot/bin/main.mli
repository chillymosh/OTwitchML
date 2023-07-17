(* MIT License

Copyright (c) 2023 Chillymosh

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. *)

exception ReconnectRequested
type priv_message = { user : string; channel : string; content : string; }
type twitch = {
  irc_token : string;
  irc_refresh_token : string option;
  channel : string;
  nick : string;
  client_id : string option;
  client_secret : string option;
  prefix : string;
  pubsub_token : string option;
  pubsub_refresh_token : string option;
}
type config = {
  owner : string option;
  twitch : twitch option;
  commands : (string * string) list option;
  pubsub_topics : string list option;
}
val print_ascii_art : unit -> unit
val irc_server : string
val irc_port : int
val read_json_file : string -> Yojson.Basic.t Async.Deferred.t
val write_json_file : string -> Yojson.Basic.t -> unit Async.Deferred.t
val extract_twitch : Yojson.Basic.t -> twitch
val extract_commands : Yojson.Basic.t -> (string * string) list
val extract_pubsub_topics : Yojson.Basic.t -> string list
val extract_config : Yojson.Basic.t -> config
val twitch_to_json :
  twitch -> [> `Assoc of (string * [> `String of string ]) list ]
val commands_to_json :
  ('a * 'b) list -> [> `Assoc of ('a * [> `String of 'b ]) list ]
val config_to_json :
  config -> Yojson.Basic.t -> [> `Assoc of (string * Yojson.Basic.t) list ]
val tcp_conn :
  (([ `Active ], Async.Socket.Address.Inet.t) Async.Socket.t *
   Async.Reader.t * Async.Writer.t)
  Async.Deferred.t
val process_commands :
  Async.Writer.t ->
  priv_message -> (string, string) Base.List.Assoc.t -> string -> unit
val parse_server_response : string -> unit
val parse_privmsg : string -> priv_message list
val irc_listener :
  Async.Reader.t ->
  Async.Writer.t ->
  (string, string) Base.List.Assoc.t -> string -> unit Async.Deferred.t
val irc_login :
  Async.Writer.t ->
  channel:string -> nick:string -> oauth:string -> unit Async.Deferred.t
val validate_token : string -> bool Async.Deferred.t
val refresh_user_token :
  string ->
  string ->
  string -> (string * string option, string) result Async.Deferred.t
val run : unit -> unit Async.Deferred.t
