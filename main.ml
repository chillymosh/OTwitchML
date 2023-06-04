open Core
open Async
open Yojson.Basic.Util
open Cohttp
open Cohttp_async

exception ReconnectRequested

type priv_message = {
  user : string;
  channel : string;
  content : string;
}

type twitch = {
  token : string ;
  channel : string ;
  nick : string ; 
  refresh_token : string option;
  client_id : string option;
  client_secret : string option;
  prefix : string option;
}

type config = {
  owner : string option;
  twitch : twitch option;
  commands : (string * string) list option;
}

type commands = (string * string) list option

let print_ascii_art () : unit =
  print_endline "@@@@@@@@@@@@@@@@@@@@@@@@@@&&####&&@@@@@@@@@@@@@@@@@@@@@@@@@@";
  print_endline "@@@@@@@@@@@@@@@@@@@@@&BGGGGGPPGGGGBBB##@@@@@@@@@@@@@@@@@@@@@";
  print_endline "@@@@@@@@@@@@@@@@@@&BGGPY?!~^^^^^^~!J5GGGG#@@@@@@@@@@@@@@@@@@";
  print_endline "@@@@@@@@@@@@@@@@BPGGY!:.             :!5BGGB&@@@@@@@@@@@@@@@";
  print_endline "@@@@@@@@@@@@@@#5PBY~:.                 ~BGPBGG&@@@@@@@@@@@@@";
  print_endline "@@@@@@@@@@@@@#5GG7^:.                  :BY~BGBPB@@@@@@@@@@@@";
  print_endline "@@@@@@@@@@@@&5BP!~^:..      ......     .?:J?:5#PG@@@@@@@@@@@";
  print_endline "@@@@@@@@@@@@GPB?~~~^:.   .........   :~!!7!^ .!5PPB@@@@@@@@@";
  print_endline "@@@@@@@@@@@@5GG7!~~~^.......::::::...JPY5BY~   .JBGG#@@@@@@@";
  print_endline "@@@@@@@@@@@@5PG7!!!~^::::^7J5555J!^:!GG5?PP^.!:  ?BBGB@@@@@@";
  print_endline "@@@@@@@@@@@@PYB5YJ7!7JYY5PYYY7!?GB7^?P5PPPJ~~~P7  ?BBPB@@@@@";
  print_endline "@@@@@@@@@@@BP5BPJBY5G5J?JJ?YY??JGG7^^:..:: :Y^Y#^ .Y#BY@@@@@";
  print_endline "@@@@@@@@@@@G55PP5BGYYGY5?.:?5GGG5!~^.    .!?P5GG:  :YB55#@@@";
  print_endline "@@@@@@@@@@@@@BJGB5J!^7GB~  :^^~?!~^:..  . 7#BBBP?~: .?BBP5G&";
  print_endline "@@@@@@@@@@@@@G5GY!~^^^Y#P^.^^:?J!^^:.     .YG5PBBBG!.^!PBBG5";
  print_endline "@@@@@@@@@@@@@P5Y!~^::^^Y#G~:^^PP!:...       . .7B5!::^^^5BBB";
  print_endline "@@@@@@@@@@@@BP5JP?:..:::7BG7^^YY^:...      ^7~:.~~:.:^^^^JBB";
  print_endline "@@@@@@@@@@@&5GYGBB7 .....:JG5!PY::... ..   ^G#GGY:J~.^^^^^?B";
  print_endline "@@@@@@@@@@@GP5JBBY^.  ....^??JJY7:.7~:5GJ^..?BBBY.^!!^^^^^^7";
  print_endline "@@@@@@@@@@@5BY7GB^?. :^..~5J7^:~5?:YY?#B##J~!?YYYJ7!^^^^^^^^";
  print_endline "@@@@@@@@@@&5B5~77J5J.!Y.~P!!5^^^~YJJB5GP5Y:.^~JY7~~~~^^^^^^^";
  print_endline "@@@@@@@@@@&PBP~!J~.PY?PJP?:7P~^!77YPGP7YYJ?J777~^~~~~~~~~~^^";
  print_endline "@@@@@@@@@@&5BGJY!:?Y??YG!~^YP~~77???JY!!?YYJ7!~~!!!!!7!!!!!~";
  print_endline "@@@@@@@@@@@BYBBPJ55~~5GJ7?Y5?!77?????????7777777777777777!!?";
  print_endline "@@@@@@@@@@@@BPBBY7JY5Y777??77????????????7777777777777777?G&";
  print_endline "@@@@@@@@@@@@@PY#Y!777777????????????????777777777777777?P&@@";
  print_endline "@@@@@@@@@@@@@#YGB?!77???????????????????7777777777777JG&@@@@";
  print_endline "@@@@@@@@@@@@@@P5BP77????????????????????77777777777JG@@@@@@@";;



let irc_server = "irc.chat.twitch.tv"
let irc_port = 6667

let read_json_file filename =
  let%bind content = Reader.file_contents filename in
  return (Yojson.Basic.from_string content)

let write_json_file filename json =
  let content = Yojson.Basic.to_string json in
  Writer.save filename ~contents:content

let extract_twitch json =
  let token = json |> member "token" |> to_string in
  let channel = json |> member "channel" |> to_string in
  let nick = json |> member "nick" |> to_string in
  let refresh_token = json |> member "refresh_token" |> to_string_option in
  let client_id = json |> member "client_id" |> to_string_option in
  let client_secret = json |> member "client_secret" |> to_string_option in
  let prefix = json |> member "prefix" |> to_string_option in

  {token; refresh_token; channel; nick; client_id; client_secret; prefix;}


let extract_commands json =
  let pairs = to_assoc json in
  List.map pairs ~f:(fun (key, value) -> (key, to_string value))

let extract_config json =
  let owner = json |> member "owner" |> to_string_option in
  let twitch = json |> member "twitch" |> to_option extract_twitch in
  let commands = json |> member "commands" |> to_option extract_commands in
  {owner; twitch; commands}



let twitch_to_json twitch =
  `Assoc [("token", `String  twitch.token);
          ("refresh_token", `String (Option.value ~default:"" twitch.refresh_token));
          ("channel", `String twitch.channel);
          ("nick", `String  twitch.nick);
          ("client_id", `String (Option.value ~default:"" twitch.client_id));
          ("client_secret", `String (Option.value ~default:"" twitch.client_secret));
          ("prefix", `String (Option.value ~default:"" twitch.prefix))]


let commands_to_json commands =
  `Assoc (List.map commands ~f:(fun (key, value) -> (key, `String value)))

let config_to_json config =
  `Assoc [
    ("owner", `String (Option.value ~default:"" config.owner));
    ("twitch", Option.value_map ~default:`Null ~f:twitch_to_json config.twitch);
    ("commands", Option.value_map ~default:`Null ~f:commands_to_json config.commands);
  ]



let tcp_conn = Tcp.connect (Tcp.Where_to_connect.of_host_and_port (Host_and_port.create ~host:irc_server ~port:irc_port))


let process_commands writer privmsg commands prefix =
  if String.is_prefix privmsg.content ~prefix then
    let command = String.chop_prefix_exn privmsg.content ~prefix in
    match List.Assoc.find ~equal:String.equal commands command with
    | Some response ->
      let user_re = Str.regexp_string "$user" in
      let response = Str.global_replace user_re privmsg.user response in
      Writer.writef writer "PRIVMSG %s :%s\r\n" privmsg.channel response
    | None -> ()


let parse_server_response line =
  match String.split line ~on:' ' with
  | ":tmi.twitch.tv" :: "376" :: _ -> 
    printf "Successfully connected to Twitch\n";
    print_ascii_art ()
  | ":tmi.twitch.tv" :: "RECONNECT" :: _ ->
    printf "Received RECONNECT command from server\n";
    raise ReconnectRequested
  | user_prefix :: "JOIN" :: channel :: _ -> 
    let user = match String.chop_prefix user_prefix ~prefix:":" with
      | Some u -> String.split u ~on:'!' |> List.hd |> Option.value ~default:""
      | None -> ""
    in
    printf "User %s has joined %s\n" user channel
  | user_prefix :: "PART" :: channel :: _ -> 
    let user = match String.chop_prefix user_prefix ~prefix:":" with
      | Some u -> String.split u ~on:'!' |> List.hd |> Option.value ~default:""
      | None -> ""
    in
    printf "User %s has left %s\n" user channel
  | _ -> ()


let parse_privmsg line =
  match String.split line ~on:' ' with
  | prefix :: "PRIVMSG" :: channel :: rest ->
    let rec extract_content = function
      | [] -> []
      | x :: xs ->
        if String.is_prefix x ~prefix:":" then
          let user = match String.chop_prefix prefix ~prefix:":" with
            | Some u -> String.split u ~on:'!' |> List.hd |> Option.value ~default:""
            | None -> ""
          in
          let content_prefix = match String.chop_prefix x ~prefix:":" with
            | Some c -> c
            | None -> x
          in
          let content = String.concat ~sep:" " (content_prefix :: xs) in
          [{ user; channel; content }]
        else
          extract_content xs
    in
    extract_content rest
  | _ -> []


let rec irc_listener reader writer commands prefix =
  let%bind line = Reader.read_line reader in
  match line with
  | `Eof -> return ()
  | `Ok line ->
    begin
      let messages = parse_privmsg line in
      List.iter messages ~f:(fun msg ->
          printf "<Channel: %s> %s: %s\n%!"
            msg.channel msg.user msg.content;
          process_commands writer msg commands prefix);
      parse_server_response line;
      if String.is_prefix line ~prefix:"PING" then (
        Writer.writef writer "PONG :tmi.twitch.tv\r\n";
      );
      irc_listener reader writer commands prefix
    end

let irc_login writer ~channel ~nick ~oauth =
  Writer.writef writer "PASS %s\r\n" oauth;
  Writer.writef writer "NICK %s\r\n" nick;
  Writer.writef writer "JOIN %s\r\n" channel;
  Writer.flushed writer


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

let refresh_user_token client_id client_secret refresh_token =
  let check_empty value =
    if String.is_empty value then
      return (Error "Missing value")
    else
      return (Ok value)
  in
  let%bind client_id_result = check_empty client_id in
  let%bind client_secret_result = check_empty client_secret in
  let%bind refresh_token_result = check_empty refresh_token in
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
        let new_refresh_token = json |> member "refresh_token" |> to_string_option in
        return (Ok (new_access_token, new_refresh_token))
      | _ -> return (Error ("Failed to refresh token: " ^ body_string))
    end
  | Error message, _, _ -> return (Error message)
  | _, Error message, _ -> return (Error message)
  | _, _, Error message -> return (Error message)



let rec run () =
  let filename = "config.json" in
  let%bind json = read_json_file filename in
  let config = extract_config json in
  let twitch = Option.value_exn config.twitch in
  let commands = Option.value ~default:[] config.commands in
  let prefix = Option.value ~default:"!" twitch.prefix in
  let channel = "#" ^ twitch.channel in
  let nick = twitch.nick in
  let oauth = "oauth:" ^ twitch.token in

  let%bind is_valid = validate_token twitch.token in
  if is_valid then (
    let%bind (_, reader, writer) = tcp_conn in
    let%bind () = irc_login writer ~channel ~nick ~oauth in
    let%bind reconnect = 
      try
        let%bind () = irc_listener reader writer commands prefix in
        return false
      with
      | ReconnectRequested -> return true
    in
    if reconnect then (
      let%bind () = Writer.close writer in
      let%bind () = Reader.close reader in
      run ()
    )
    else
      return ()
  )
  else (
    match twitch.refresh_token, twitch.client_id, twitch.client_secret with
    | Some refresh_token, Some client_id, Some client_secret ->
      printf "Token validation failed, attempting to refresh token...\n";
      (try
         let%bind refresh_result = refresh_user_token client_id client_secret refresh_token in
         begin
           match refresh_result with
           | Ok (new_access_token, new_refresh_token) ->
             printf "Refreshed token: %s\n" new_access_token;
             let twitch = {twitch with token = new_access_token; refresh_token = new_refresh_token} in
             let config = {config with twitch = Some twitch} in
             let%bind () = write_json_file filename (config_to_json config) in
             run ()
           | Error message ->
             printf "Failed to refresh token: %s\n" message;
             exit 1
         end
       with
       | exn ->
         printf "An error occurred while refreshing token: %s\n" (Exn.to_string exn);
         exit 1)
    | _ ->
      printf "Token validation failed and missing required data for token refresh\n";
      exit 1
  )


let () =
  let _ = run () in
  never_returns (Scheduler.go ())