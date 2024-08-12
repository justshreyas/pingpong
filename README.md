A sample command-line application with an entrypoint in `host/bin/`, library code
in `host/lib/`. Implements a Virtual Ping Pong Championship.

Requirements : Dart

API
1. /join = POST request; Used to join the championship; Requires "player_id" and "player_password"; Responds with bearer token
2. /move = POST request; Used to register game move; Requires "offence"(int) or "defence"(int array); Requires bearer auth token
3. /game = GET request; Used to get game status; Requires bearer auth token
4. / = GET request; Quick doc of all available routes

Championship Testing Instructions:
1. Refer to host/README_commands.md for individual commands for players
2. Host/Referee runs as a local server.
3. Each player client is an independent terminal window.
4. Client communicates with Server using cURL commands.
5. After Championship is over, the game logs will be dumped in the console (treated as "export").
6. After Log Dump, server will be safe to shut down.