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

exception ReconnectException
type twitch = {
  irc_token : string option;
  irc_refresh_token : string option;
  channel : string option;
  nick : string option;
  client_id : string;
  client_secret : string;
  prefix : string option;
  pubsub_token : string;
  pubsub_refresh_token : string;
}
type config = {
  owner : string option;
  twitch : twitch;
  commands : (string * string) list option;
  pubsub_topics : string list;
}
val read_json_file : string -> Yojson.Basic.t Conduit_async.io
val write_json_file : string -> Yojson.Basic.t -> unit Conduit_async.io
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
val validate_token : string -> bool Conduit_async.io
val refresh_user_token : twitch -> (twitch, string) result Conduit_async.io
val subscribe_message : twitch -> string list -> string
val process_json : Yojson.Basic.t -> Yojson.Basic.t
val client :
  string option -> string option -> Uri.t -> string -> unit Conduit_async.io
val run : unit -> unit Conduit_async.io
