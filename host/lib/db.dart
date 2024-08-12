/// Database of all registered users for the championship.
/// Hardcoded for demo purposes.
final Map<String, Map<String, dynamic>> registeredUsers = {
  '1': {
    "player_id": '1',
    "player_name": "Eliud",
    "player_password": "Eliud",
    "defenceSetLength": 8,
    "token": "youaretheone",
  },
  '2': {
    "player_id": '2',
    "player_name": "Mo",
    "player_password": "Mo",
    "defenceSetLength": 8,
    "token": "toosimplefortwo",
  },
  '3': {
    "player_id": '3',
    "player_name": "Mary",
    "player_password": "Mary",
    "defenceSetLength": 7,
    "token": "threedee",
  },
  '4': {
    "player_id": '4',
    "player_name": "Usain",
    "player_password": "Usain",
    "defenceSetLength": 7,
    "token": "fortified",
  },
  '5': {
    "player_id": '5',
    "player_name": "Paula",
    "player_password": "Paula",
    "defenceSetLength": 6,
    "token": "fifthharmony",
  },
  '6': {
    "player_id": '6',
    "player_name": "Galen",
    "player_password": "Galen",
    "defenceSetLength": 6,
    "token": "idontwatchcricket",
  },
  '7': {
    "player_id": '7',
    "player_name": "Shalane",
    "player_password": "Shalane",
    "defenceSetLength": 5,
    "token": "sevensevenseven",
  },
  '8': {
    "player_id": '8',
    "player_name": "Haile",
    "player_password": "Haile",
    "defenceSetLength": 5,
    "token": "sevenatenine",
  },
};

/// Record of all the users who are waiting in a virtual lobby
final List<String> userLobby = [];

/// Record of all the users who are still competing in the championship.
final List<String> competingPlayers = [];

/// Record of all users joined but no longer competing in the championship.
final List<String> noncompetingPlayers = [];

/// Database of all drawn games
final Map<String, Map<String, dynamic>> games = {};

/// Database of game moves
final List<Map<String, dynamic>> gameMoves = [];

///Used to define points to be scored in a game
const int kPointsToWinAGame = 5; //1

///Used to keep count of game draw rounds
int gameDrawn = 0;
