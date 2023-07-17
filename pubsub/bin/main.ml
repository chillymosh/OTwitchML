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

open Core
open Websocket_async
open Yojson.Basic.Util
open Async
open Cohttp
open Cohttp_async

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

let read_json_file filename =
  let%bind content = Reader.file_contents filename in
  return (Yojson.Basic.from_string content)

let write_json_file filename json =
  let content = Yojson.Basic.to_string json in
  Writer.save filename ~contents:content

let extract_twitch json =
  let irc_token = json |> member "irc_token" |> to_string_option in
  let irc_refresh_token = json |> member "irc_refresh_token" |> to_string_option in
  let channel = json |> member "channel" |> to_string_option in
  let nick = json |> member "nick" |> to_string_option in
  let prefix = json |> member "prefix" |> to_string_option in
  let pubsub_token = json |> member "pubsub_token" |> to_string in
  let pubsub_refresh_token = json |> member "pubsub_refresh_token" |> to_string in
  let client_id = json |> member "client_id" |> to_string in
  let client_secret = json |> member "client_secret" |> to_string in

  {irc_token; irc_refresh_token ; channel; nick; prefix; pubsub_token; pubsub_refresh_token; client_id; client_secret;}


(* Most of the below is not neccessarily needed, 
   can just push original json back into config.json like pubsub_topics.
   Just did this as a learning exercise*)

let extract_commands json =
  let pairs = Yojson.Basic.Util.to_assoc json in
  List.map pairs ~f:(fun (key, value) -> (key, to_string value))


let extract_pubsub_topics json =
  let pairs = to_assoc json in
  List.map pairs ~f:(fun (key, value) -> key ^ "." ^ Yojson.Basic.Util.to_string value)


let extract_config json =
  let owner = json |> member "owner" |> to_string_option in
  let twitch = json |> member "twitch" |>  extract_twitch in
  let commands = json |> member "commands" |> to_option extract_commands in
  let pubsub_topics = json |> member "pubsub_topics" |>  extract_pubsub_topics in
  { owner; twitch; commands; pubsub_topics}

let twitch_to_json twitch =
  `Assoc [("irc_token", `String (Option.value ~default:"" twitch.irc_token));
          ("irc_refresh_token", `String (Option.value ~default:"" twitch.irc_refresh_token));
          ("channel", `String (Option.value ~default:"" twitch.channel));
          ("nick", `String (Option.value ~default:""  twitch.nick));
          ("client_id", `String twitch.client_id);
          ("client_secret", `String twitch.client_secret);
          ("prefix", `String (Option.value ~default:"" twitch.prefix));
          ("pubsub_token", `String  twitch.pubsub_token);
          ("pubsub_refresh_token", `String twitch.pubsub_refresh_token)]


let commands_to_json commands =
  `Assoc (List.map commands ~f:(fun (key, value) -> (key, `String value)))

let config_to_json config json =
  let pubsub_topics = json |> member "pubsub_topics" in
  `Assoc [
    ("owner", `String (Option.value ~default:"" config.owner));
    ("twitch", twitch_to_json config.twitch);
    ("commands", Option.value_map ~default:`Null ~f:commands_to_json config.commands);
    ("pubsub_topics", pubsub_topics)
  ]

let validate_token token =
  let uri = Uri.of_string "https://id.twitch.tv/oauth2/validate" in
  let headers = Header.add (Header.init ()) "Authorization" ("OAuth " ^ token) in
  let%bind response, body = Client.get ~headers uri in
  let%bind body_string = Cohttp_async.Body.to_string body in
  let status = Response.status response |> Cohttp.Code.code_of_status in
  let is_valid = status = 200 in
  if is_valid then (
    let () = printf "Token validation successful!\n%s\n" body_string in
    return is_valid
  )
  else (
    return false
  )

let refresh_user_token twitch =
  let check_empty value =
    if String.is_empty value then
      return (Error "Missing value")
    else
      return (Ok value)
  in
  let%bind client_id_result = check_empty twitch.client_id in
  let%bind client_secret_result = check_empty twitch.client_secret in
  let%bind refresh_token_result = check_empty twitch.pubsub_refresh_token in
  match client_id_result, client_secret_result, refresh_token_result with
  | Ok client_id, Ok client_secret, Ok refresh_token ->
    let uri = Uri.of_string "https://id.twitch.tv/oauth2/token" in
    let body = [
      ("grant_type", ["refresh_token"]);
      ("refresh_token", [refresh_token]);
      ("client_id", [client_id]);
      ("client_secret", [client_secret]);
    ] |> Uri.encoded_of_query in
    let headers = Cohttp.Header.init () in
    let headers = Cohttp.Header.add headers "Content-Type" "application/x-www-form-urlencoded" in
    let%bind response, body = Client.post ~body:(Cohttp_async.Body.of_string body) ~headers uri in
    let%bind body_string = Cohttp_async.Body.to_string body in
    begin
      match Response.status response |> Cohttp.Code.code_of_status with
      | 200 -> 
        let json = Yojson.Basic.from_string body_string in
        let new_access_token = json |> member "access_token" |> to_string in
        let new_refresh_token = json |> member "refresh_token" |> to_string in
        let updated_twitch = { twitch with pubsub_token = new_access_token; pubsub_refresh_token = new_refresh_token } in
        return (Ok updated_twitch)
      | _ -> return (Error ("Failed to refresh token: " ^ body_string))
    end
  | Error message, _, _ -> return (Error message)
  | _, Error message, _ -> return (Error message)
  | _, _, Error message -> return (Error message)



let subscribe_message twitch pubsub_topics =
  let msg = `Assoc [
      ("type", `String "LISTEN");
      ("data", `Assoc [
          ("topics", `List (List.map ~f:(fun str -> `String str) pubsub_topics));
          ("auth_token", `String twitch.pubsub_token);
        ]);] in
  Yojson.Basic.to_string msg

let rec process_json json =
  match json with
  | `String s -> (try Yojson.Basic.from_string s with _ -> json)
  | `Assoc assoc -> `Assoc (List.map ~f:(fun (k, v) -> (k, process_json v)) assoc)
  | `List l -> `List (List.map ~f:process_json l)
  | other -> other
  
  

let client protocol extensions uri subscription =
  let host = Option.value_exn ~message:"no host in uri" Uri.(host uri) in
  let port =
    match (Uri.port uri, Uri_services.tcp_port_of_uri uri) with
    | Some p, _ -> p
    | None, Some p -> p
    | _ -> invalid_arg "port cannot be inferred from URL"
  in
  let scheme = Option.value_exn ~message:"no scheme in uri" Uri.(scheme uri) in
  let tcp_fun (r, w) =
    let module C = Cohttp in
    let extra_headers = C.Header.init () in
    let extra_headers =
      Option.value_map protocol ~default:extra_headers ~f:(fun proto ->
          C.Header.add extra_headers "Sec-Websocket-Protocol" proto)
    in
    let extra_headers =
      Option.value_map extensions ~default:extra_headers ~f:(fun exts ->
          C.Header.add extra_headers "Sec-Websocket-Extensions" exts)
    in
    let r, w =
      client_ez ~extra_headers ~heartbeat:Time_ns.Span.(of_int_sec 5) uri r w
    in
    Pipe.write w subscription >>= fun () ->
    Deferred.all_unit
      [
        Pipe.transfer
          Reader.(pipe @@ Lazy.force stdin)
          w
          ~f:(fun s -> String.chop_suffix_exn s ~suffix:"\n");
          Pipe.transfer r Writer.(pipe @@ Lazy.force stdout) ~f:(fun s -> 
            try 
              let json = Yojson.Basic.from_string s in 
              let processed_json = process_json json in
              if (match processed_json with
                | `Assoc [("type", `String "RECONNECT")] -> true
                | _ -> false)
              then raise ReconnectException
              else (Yojson.Basic.pretty_to_string processed_json) ^ "\n"
            with
            | Yojson.Json_error _ -> "Invalid JSON: " ^ s ^ "\n"
          );
      ]
  in
  Unix.Addr_info.get ~service:(string_of_int port) ~host [] >>= function
  | [] -> failwithf "DNS resolution failed for %s" host ()
  | { ai_addr; _ } :: _ ->
    let addr =
      match (scheme, ai_addr) with
      | _, ADDR_UNIX path -> `Unix_domain_socket path
      | "https", ADDR_INET (h, p) | "wss", ADDR_INET (h, p) ->
        let h = Ipaddr_unix.of_inet_addr h in
        `OpenSSL (h, p, Conduit_async.V2.Ssl.Config.create ())
      | _, ADDR_INET (h, p) ->
        let h = Ipaddr_unix.of_inet_addr h in
        `TCP (h, p)
    in
    Conduit_async.V2.connect addr >>= tcp_fun



let run () =
  let cfg = "config.json" in
  let%bind json = read_json_file cfg in
  let config = extract_config json in
  let twitch = config.twitch in
  let%bind is_valid = validate_token twitch.pubsub_token in
  let url = Uri.of_string "wss://pubsub-edge.twitch.tv:443" in
  match is_valid with
  | true -> 
    let subscription = subscribe_message twitch config.pubsub_topics in
    client None None url subscription
  | false ->
    match%bind refresh_user_token twitch with
    | Ok refreshed_twitch ->
      let config = {config with twitch = refreshed_twitch} in
      let%bind () = write_json_file cfg (config_to_json config json) in
      let subscription = subscribe_message refreshed_twitch config.pubsub_topics in
      client None None url subscription
    | Error msg ->
      printf "Failed to refresh token: %s\n" msg;
      exit 1

let () = 
  don't_wait_for (run());
  never_returns (Scheduler.go ())
