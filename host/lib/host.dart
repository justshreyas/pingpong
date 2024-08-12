import 'dart:convert';
import 'package:host/db.dart';
import 'package:shelf/shelf.dart';

int calculate() {
  return 6 * 7;
}

Response rootHandler(Request request) {
  return Response.ok('rootHandler');
}

Future<Response> joinHandler(Request request) async {
  final requestData = await request.readAsString();
  final requestJson = jsonDecode(requestData) as Map<String, dynamic>;
  final playerId = requestJson['player_id'];
  final playerName = requestJson['player_name'];

  final Map<String, String> pMap = {
    'player_id': playerId,
    'player_name': playerName,
  };


  // Add the player to lobby
  //TODO : check if user is registered and not joined already
  userLobby.add(pMap);
  competingPlayers.add(pMap);

  if (userLobby.length == registeredUsers.length) {
    print('All players have joined. Proceeding to game drawing phase.');
    drawGames();
  }

  // Check if all players have joined
  while (competingPlayers.length != registeredUsers.length) {
    await Future.delayed(Duration(seconds: 2));
  }

  final gameMap = getGame(playerId);
  final secretCode = getCode(playerId);

  return Response.ok(jsonEncode({"secret_code": secretCode, ...gameMap}));
}

Future<Response> gameHandler(Request request) async {
  //add to user lobby when won elsewhere

  // if user in non competing, send invalid req err
  // if user is competing,
  // check lobby length with competing length
  // if not, wait
  // if yes, proceed to get game and respond
  return Response.ok('Game Handler');
}

Future<Response> moveHandler(Request request) async {
  try {
    final requestData = await request.readAsString();
    final requestJson = jsonDecode(requestData) as Map<String, dynamic>;
    final token = request.headers['authorization']?.split(" ").last;

    final playerId =
        secretCodes.entries.firstWhere((entry) => entry.value == token).key;

    final int? offence = requestJson['offence'];
    final List<int>? defence = (requestJson['defence'] as List<dynamic>?)
        ?.map((i) => i as int)
        .toList();
    // TODO : check for correct defence length

    // 1. get open game for user id
    final currentGame = getGame(playerId);
    final gameId = currentGame['game_id'];
    if (currentGame.isEmpty) {
      // TODO : send instruction to query join or game endpt
      // if user is not in the join list
      return Response.forbidden(
          {"reason": "No open games available for you"}.toString());
    }

    // 2.a verify user can make this move
    bool mustOffend = currentGame['last_scored_player_id'] == playerId;
    bool isOffending = offence != null;
    bool isDefending = defence != null;

    if ((mustOffend && isDefending) || (!mustOffend && isOffending)) {
      return Response.badRequest(
          body: {"reason": mustOffend ? "You must offend" : "You must defend"}
              .toString());
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
        late final Map<String, String> loser;
        late final Map<String, String> winner;
        if (p1Score == kPointsToWinAGame) {
          // remove p2
          loser = competingPlayers
              .where((u) => u['player_id'] == currentGame['player2_id'])
              .first;
          winner = competingPlayers
              .where((u) => u['player_id'] == currentGame['player1_id'])
              .first;
        } else {
          // remove p1
          loser = competingPlayers
              .where((u) => u['player_id'] == currentGame['player1_id'])
              .first;
          winner = competingPlayers
              .where((u) => u['player_id'] == currentGame['player2_id'])
              .first;
        }
        competingPlayers.remove(loser);
        noncompetingPlayer.add(loser);
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
        currentGame['last_scored_player_id'] == playerId;

    nextMoveResponse = thisPlayerWinsTheRound
        ? Response.ok('You won this round!'
            '\nYou=$myScore VS Opponent=$oppScore\n'
            'Pick an offence.')
        : Response.ok('You lost this round..'
            '\nYou=$myScore VS Opponent=$oppScore\n'
            ' Pick a defence.');

    //4.a.1 check if status of game is over
    if (updatedGame['status'] == 'over') {
      gameOverResponse = updatedGame['last_scored_player_id'] == playerId
          ? Response.ok(
              'Game over. Query \'/game\' endpoint to find the next draws.')
          : Response.ok('Game over. You are out of the tournament.'
              ' Thank you for participating.');

      if (games.values.where((game) => game['status'] != 'over').isEmpty) {
        // 4.b when status of all games becomes completed, check competing players length
        //    proceed to draw new round or declare winner
        if (competingPlayers.length == 1) {
          if (competingPlayers.first['player_id'] == playerId) {
            championshipWinnerResponse = Response.ok(
                'Last game over. You are crowned the championship winner! 38D');
          } else {
            championshipWinnerResponse = Response.ok(
                'Last game over. You did not win the championship :(');
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

Response resultHandler(Request request) {
  return Response.ok('resultHandler');
}

Future<void> drawGames() async {
  // final random = Random();
  final matchups = <String, Map<String, dynamic>>{};

  // // Shuffle players and create matchups
  // players.shuffle(random);
  for (var i = 0; i < competingPlayers.length; i += 2) {
    final player1 = competingPlayers[i];
    final player2 = competingPlayers[i + 1];
    final gameId = 'game_${(i ~/ 2) + 1}';
    matchups[gameId] = {
      'game_id': gameId,
      'status': 'drawn',
      'player1_id': player1['player_id']!,
      'player2_id': player2['player_id']!,
      'player1_score': 0,
      'player2_score': 0,
      'last_scored_player_id': player1['player_id'],
    };
  }

  games.addAll(matchups);
  userLobby.retainWhere((p) => false);
}

Map<String, dynamic> getGame(String playerId) {
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

String getCode(String playerId) {
  return secretCodes[playerId]!;
}

void exportChampionshipDetails(){
  print(games);
}