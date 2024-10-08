import 'dart:convert';
import 'package:host/db.dart';
import 'package:shelf/shelf.dart';

int calculate() {
  return 6 * 7;
}

// * Handlers
Response rootHandler(Request request) {
  return Response.ok("""
Welcome to the Ping Pong Championship.
POST /join with "player_name" and "player_password"
POST /move with "offence" or "defence" as instructed
GET /game for game instructions
""");
}

Future<Response> joinHandler(Request request) async {
  final requestData = await request.readAsString();
  final requestJson = jsonDecode(requestData) as Map<String, dynamic>;
  final playerName = requestJson['player_name'];
  final playerPassword = requestJson['player_password'];

  final token = authenticate(playerName, playerPassword);
  if (token == null) {
    return Response.unauthorized(jsonEncode({
      "reason": "Invalid credentials",
      "instruction": "Try again with valid credentials",
    }));
  }

  final playerId = verifyToken(token)!;

  // Add the player to lobby
  if (userLobby.contains(playerId)) {
    return Response.forbidden(jsonEncode({
      "reason": "Already joined the championship",
      "instruction": "Query the /game endpoint to know about your next move",
    }));
  }
  userLobby.add(playerId);
  competingPlayers.add(playerId);

  if (userLobby.length == registeredUsers.length) {
    print('All players have joined. Proceeding to draw games for this round.');
    drawGames();
  }

  // Check if all players have joined
  while (competingPlayers.length != registeredUsers.length) {
    await Future.delayed(Duration(seconds: 2));
  }

  final gameMap = getAvailableGame(playerId);
  final bearerToken = getToken(playerId);

  return Response.ok(jsonEncode({
    "token": bearerToken,
    "instruction": gameMap['instruction'],
  }));
}

Future<Response> gameHandler(Request request) async {
  final token = request.headers['authorization']?.split(" ").last;

  final tokenVerification = verifyToken(token ?? "no-token");
  if (tokenVerification == null) {
    return Response.unauthorized('Failed token verification');
  }

  final playerId = tokenVerification;

  // if user in non competing, send invalid req err
  if (noncompetingPlayers.where((player) => player == playerId).isNotEmpty) {
    return Response.forbidden(
        'You have already been eliminated from the gameplay.');
  }

  final game = getAvailableGame(playerId);
  // if yes, proceed to get game and respond
  if (game.isEmpty) {
    return Response.ok('Other games in this round are still in progress.\n'
        'Try again in some time for updates.');
  } else {
    return Response.ok(jsonEncode(game)); 
  }
}

Future<Response> moveHandler(Request request) async {
  try {
    final requestData = await request.readAsString();
    final requestJson = jsonDecode(requestData) as Map<String, dynamic>;
    final token = request.headers['authorization']?.split(" ").last;

    final tokenVerification = verifyToken(token ?? "no-token");
    if (tokenVerification == null) {
      return Response.unauthorized('Failed token verification');
    }

    final playerId = tokenVerification;

    final int? offence = requestJson['offence'];
    final List<int>? defence = (requestJson['defence'] as List<dynamic>?)
        ?.map((i) => i as int)
        .toList();

    // 1. get open game for user id
    final currentGame = getAvailableGame(playerId);
    final gameId = currentGame['game_id'];
    if (currentGame.isEmpty) {
      return Response.forbidden(jsonEncode({
        "reason": "No open games available right now",
        "instruction":
            "Query the /game end point for information about next game"
      }));
    }

    // 2.a verify user can make this move
    bool mustOffend = currentGame['last_scored_player_id'] == playerId;
    bool isOffending = offence != null;
    bool isDefending = defence != null;

    if ((mustOffend && isDefending) || (!mustOffend && isOffending)) {
      return Response.badRequest(
          body: jsonEncode(
              {"reason": mustOffend ? "You must offend" : "You must defend"}));
    }

    if (isDefending &&
        defence.length != registeredUsers[playerId]!['defenceSetLength']) {
      return Response.badRequest(
          body: jsonEncode({
        "reason": 'You must choose a defence that is '
            '${registeredUsers[playerId]!['defenceSetLength']} long'
      }));
    }
    // 2.b check if they  have not already registered move

    Response? nextMoveResponse;
    Response? gameOverResponse;
    Response? championshipWinnerResponse;

    // 3. check if there are any pending moves for this game id,
    final pendingMove = gameMoves
        .where((move) => move['game_id'] == currentGame['game_id'])
        .firstOrNull;

    if (pendingMove != null && pendingMove.isNotEmpty) {
      // 3.a if yes, proceed to compute and, change game status
      late bool thisPlayerWinsCurrentRound;
      if (isOffending) {
        final List<int> opponentDefence = pendingMove['defence'];
        thisPlayerWinsCurrentRound = !opponentDefence.contains(offence);
      } else {
        final int opponentOffence = pendingMove['offence'];
        thisPlayerWinsCurrentRound =
            defence?.contains(opponentOffence) ?? false;
      }

      final bool isPlayer1 = currentGame['player1_id'] == playerId;

      gameMoves.remove(pendingMove);
      // score modification, playerid modification
      if (thisPlayerWinsCurrentRound) {
        if (isPlayer1) {
          games[gameId]!['player1_score']++;
        } else {
          games[gameId]!['player2_score']++;
        }
        games[gameId]!['last_scored_player_id'] = playerId;
      } else {
        late final String otherPlayerId;
        if (isPlayer1) {
          games[gameId]!['player2_score']++;
          otherPlayerId = games[gameId]!['player2_id'];
        } else {
          games[gameId]!['player1_score']++;
          otherPlayerId = games[gameId]!['player1_id'];
        }
        games[gameId]!['last_scored_player_id'] = otherPlayerId;
      }

      // player list modification
      final p1Score = games[gameId]!['player1_score'];
      final p2Score = games[gameId]!['player2_score'];
      late final String status;

      if (p1Score == kPointsToWinAGame || p2Score == kPointsToWinAGame) {
        status = 'over';

        // 3.a.2 if game is over, update noncompeting player
        late final String loser;
        late final String winner;
        if (p1Score == kPointsToWinAGame) {
          // remove p2
          loser = competingPlayers
              .where((u) => u == currentGame['player2_id'])
              .first;
          winner = competingPlayers
              .where((u) => u == currentGame['player1_id'])
              .first;
        } else {
          // remove p1
          loser = competingPlayers
              .where((u) => u == currentGame['player1_id'])
              .first;
          winner = competingPlayers
              .where((u) => u == currentGame['player2_id'])
              .first;
        }
        competingPlayers.remove(loser);
        noncompetingPlayers.add(loser);
        userLobby.add(winner);
      } else {
        status = 'computed';
      }
      // game status modification
      games[gameId]!['status'] = status;
    } else {
      // 3.b.1 if no, add move to moves, change game status to pending
      gameMoves.add({
        'game_id': currentGame['game_id'],
        if (mustOffend) 'offence': offence,
        if (!mustOffend) 'defence': defence,
      });
      // int index = games.indexWhere((game)=>);
      games[gameId]!['status'] = 'pending';

      // 3.b.2 long poll till game status changes to computed

      while (
          //games[gameId]!['status']
          games[gameId]!['status'] == 'pending') {
        await Future.delayed(Duration(seconds: 1));
      }
    }

    // assign responses
    final updatedGame = games[gameId]!;
    // next move
    final isPlayer1 = updatedGame['player1_id'] == playerId;
    final p1Score = updatedGame['player1_score'];
    final p2Score = updatedGame['player2_score'];
    final int myScore = isPlayer1 ? p1Score : p2Score;
    final int oppScore = isPlayer1 ? p2Score : p1Score;
    final bool thisPlayerWinsTheRound =
        updatedGame['last_scored_player_id'] == playerId;

    nextMoveResponse = thisPlayerWinsTheRound
        ? Response.ok('You won this round!'
            '\nYou=$myScore VS Opponent=$oppScore\n'
            'Pick an offence.')
        : Response.ok('You lost this round..'
            '\nYou=$myScore VS Opponent=$oppScore\n'
            ' Pick a defence.');

    //4.a.1 check if status of game is over
    if (updatedGame['status'] == 'over') {
      gameOverResponse = thisPlayerWinsTheRound
          ? Response.ok(
              'Game over. Query \'/game\' endpoint to find the next draws.')
          : Response.ok('Game over. You are out of the tournament.'
              ' Thank you for participating.');

      if (games.values.where((game) => game['status'] != 'over').isEmpty) {
        // 4.b when status of all games becomes completed, check competing players length
        //    proceed to draw new round or declare winner
        if (competingPlayers.length == 1) {
          if (competingPlayers.first == playerId) {
            championshipWinnerResponse = Response.ok(
                'Last game over. You are crowned the championship winner! 38D');
          } else {
            championshipWinnerResponse = Response.ok(
                'Last game over. You did not win the championship :(');
            exportChampionshipDetails();
          }
        } else {
          drawGames();
        }
      }
    }

    return championshipWinnerResponse ?? gameOverResponse ?? nextMoveResponse;
  } catch (e, st) {
    print(e);
    print(st);
  }
  return Response.internalServerError();
}

// * Helpers
/// Matches up all the competing players to draw games for a round
Future<void> drawGames() async {
  // final random = Random();
  final matchups = <String, Map<String, dynamic>>{};
  gameDrawn++;

  // // Shuffle players and create matchups
  // players.shuffle(random);
  for (var i = 0; i < competingPlayers.length; i += 2) {
    final player1 = competingPlayers[i];
    final player2 = competingPlayers[i + 1];
    final gameId = 'draw_${gameDrawn}_game${(i ~/ 2) + 1}';
    matchups[gameId] = {
      'game_id': gameId,
      'draw_level': gameDrawn,
      'status': 'drawn',
      'player1_id': player1,
      'player2_id': player2,
      'player1_score': 0,
      'player2_score': 0,
      'last_scored_player_id': player1,
    };
  }

  games.addAll(matchups);
  print("Matchups complete. Games Drawn.");
  userLobby.retainWhere((p) => false);
}

/// Get currently available game for the mentioned playerId
Map<String, dynamic> getAvailableGame(String playerId) {
  final openGames = games.values.where((game) => game['status'] != 'over');

  for (var game in openGames) {
    if (game['player1_id'] == playerId) {
      return {
        "instruction": "You have to pick an offence",
        ...game,
      };
    } else if (game['player2_id'] == playerId) {
      return {
        "instruction": "You have to pick a defence",
        ...game,
      };
    }
  }
  return {};
}

/// Get token associated with specified playerId
String getToken(String playerId) {
  return registeredUsers[playerId]!['token'];
}

/// Print details of all the games
void exportChampionshipDetails() {
  print('\n\n----Ping Pong Championship has ended----');
  print('\n\nGAME LOGS :\n');

  for (var i = gameDrawn; i >0; i--) {
    final gamesInThisRound = games.values.where((game)=>game['draw_level']==i);

    if(i==gameDrawn){
      print('Finals:');
    }else if(i==gameDrawn-1){
      print('Semi-Finals:');
    }else{
      print('Qualifier Round $i');
    }
    for (var game in gamesInThisRound) {
      print(game);
    }
  }
  
  print('\n\n----Safe to SHUTDOWN SERVER----');
}

/// Returns the authentication token for this user if successful
String? authenticate(String name, String password) {
  final player = registeredUsers.values
      .where((player) => player['player_name'] == name)
      .firstOrNull;
  if (player != null) {
    final passwordMatches = player['player_password'] == password;
    if (passwordMatches) {
      return player['token'];
    }
  }
  return null;
}

/// Verifies if token is valid and returns associated player id
String? verifyToken(String token) {
  return registeredUsers.entries
      .where((entry) => entry.value['token'] == token)
      .firstOrNull
      ?.key;
}
