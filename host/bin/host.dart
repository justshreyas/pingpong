import 'package:host/host.dart' as host;
import 'package:host/host.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

void main(List<String> arguments) async {
  var router = Router();
  router.get('/', rootHandler);
  router.post('/join', host.joinHandler);
  router.get('/game', gameHandler);
  router.post('/move', moveHandler);

  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  var server = await io.serve(handler, 'localhost', 8080);
  print('Server listening on port ${server.port}');
  print('\n\n----Ping Pong Championship has started----');
  print('Registered players can now query the /join end point');
}
