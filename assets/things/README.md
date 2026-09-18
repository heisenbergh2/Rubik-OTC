# Adding client versions

For protocol 15.30, put the client-nine asset catalog and its referenced files in
`assets/things/assets/`. The client loads this directory as `/things/assets/`.

The repository does not ship the game catalog or sprite files. The shared
`assets.json.sha256` sits at `assets/things/assets.json.sha256`; keep its value
in sync with the server's asset identifier. Other client versions can use
version-specific folders if configured to do so.

For the list of supported client versions see `modules/gamelib/game.lua`

# Example configurations

spr/dat:
`assets/things/860/ (spr and dat files there)`

assets:
`assets/things/assets/ (catalog-content.json and all referenced asset files)`
