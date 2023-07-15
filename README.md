# OTwitchML

Since this is just a learning exercise for oCaml it is not really a serious entry into the codejam.
I also don't expect many people to understand what's going on or even be able to compile :)
This also only compiles on Unix / Linux systems (Possibly also Mac)

Basic Twitch Chatbot in oCaml

The packages that need to be installed are async, async_ssl, core, ppx_let, cohttp, cohttp-async, yojson
```
opam-version: "2.0"
depends: [
  "dune" {>= "3.9.0"}
  "ocaml" {>= "5.0.0"}
  "async" {>= "v0.15.0"}
  "async_ssl" {>= "v0.15.0"}
  "cohttp" {>= "5.1.0"}
  "cohttp-async" {>= "5.1.0"}
  "ppx_let" {>= "v0.15.0"}
  "yojson" {>= "2.1.0"}
]
```

Configure the config.json with your Twitch user auth details for the bot account and the prefix for commands you would like to use.

The config.json can be shared across both pubsub and chatbot. The oauth tokens will refresh as long as you use the same client ID and secret that generated both.

Ideally you would be using dune, clone the repo, cd into the directory e.g. chatbot and run `dune build` then you can run your executable in `./_build/install/default/bin`
This saves you having to do the manual compile below

To compile directly after you have installed oCaml and the dependencies via opam:
 ```
 ocamlfind ocamlopt -thread -package async,ppx_let,yojson,cohttp,cohttp-async -c main.mli
 ocamlfind ocamlopt -thread -package async,ppx_let,yojson,cohttp,cohttp-async -linkpkg -o chatbot main.ml
 ```
 
 If you use $user in a command response then it will replace it with the name of the chatter who invoked the command.

For pubsub:
```
opam-version: "2.0"
depends: [
  "dune" {>= "3.9.0"}
  "ocaml" {>= "5.0.0"}
  "async" {>= "v0.15.0"}
  "websocket-async" {>= "2.16"}
  "cohttp" {>= "5.1.0"}
  "cohttp-async" {>= "5.1.0"}
  "ppx_let" {>= "v0.15.0"}
  "yojson" {>= "2.1.0"}
  "core_unix" {>= "v0.15.2"}
]
```

Manual build
```
ocamlfind ocamlopt -thread -package async,core,websocket-async,core_unix.command_unix,cohttp,cohttp-async,yojson,ppx_let -c main.mli
ocamlfind ocamlopt -thread -package async,core,websocket-async,core_unix.command_unix,cohttp,cohttp-async,yojson,ppx_let -linkpkg -o pubsub main.ml
```