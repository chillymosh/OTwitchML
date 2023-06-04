# OTwitchML
Basic Twitch Bot in oCaml

The packages that need to be installed are async, async_ssl, core, ppx_let, cohttp, cohttp-async, yojson

Configure the config.json with your Twitch user auth details for the bot account and the prefix for commands you would like to use.

To compile after you have installed oCaml
 ```
 ocamlfind ocamlopt -thread -package async,ppx_let,yojson,cohttp,cohttp-async -linkpkg -o your_app_name main.ml
 ```
 
 If you use $user in a command response then it will replace it with the name of the chatter who invoked the command.
