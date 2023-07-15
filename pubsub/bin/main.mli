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
