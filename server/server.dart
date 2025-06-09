import 'dart:io';
import 'dart:async';
import 'dart:convert';


class Room{
  final String name;
  final int capacity;
  final Set<Client> clients = {};

  Room(this.name, {this.capacity = 3});

  Map<String,dynamic> toJson(){
    return {
      "name" : name,
      "capacity" : capacity,
      "occupancy" : clients.length,
    };
  }
}

class Client {
  final Socket socket;
  final String id;
  String? currentRoom;
  StringBuffer buffer = StringBuffer();

  Client(this.socket, this.id);
}

class TcpServerForWidget{
  ServerSocket? server;
  final Map<String, Client> clients = {};
  final Map<String, Room> rooms = {};
  int clientIdCounter = 0;

  TcpServerForWidget(){
    rooms["General"] = Room("General");
  }

  Future<void> start({String host="0.0.0.0", int port = 1234}) async {
    server = await ServerSocket.bind(host, port);

    server!.listen((Socket socket){
      handleNewClient(socket);
    });
  }

  void stop() {
    for (Client client in clients.values) {
      client.socket.close();
    }
    clients.clear();
    rooms.clear();
    server?.close();
  }

  List<Client> getGamePlayers(String roomName) {
    Room? room = rooms[roomName];
    if (room == null) return [];

    return room.clients.take(3).toList();
  }

  void handleNewClient(Socket socket){
    final clientId = "client_${++clientIdCounter}";
    final client = Client(socket, clientId);
    clients[clientId] = client;

    print("new connection: $clientId from ${socket.remoteAddress.address}:${socket.remotePort}");

    socket.listen((data){
      client.buffer.write(utf8.decode(data));

      String bufferContent = client.buffer.toString();
      List<String> lines = bufferContent.split('\n');

      client.buffer = StringBuffer(lines.removeLast());

      for(String line in lines){
        line = line.trim();
        if(line.isNotEmpty){
          handleClientMessage(client, line);
        }
      }
    },
        onError: (error){
          print("client $clientId error: $error");
          removeClient(client);
        },
        onDone: (){
          print("Client $clientId disconnected");
          removeClient(client);
        }
    );
  }

  void handleClientMessage(Client client, String message) {
    try {
      Map<String, dynamic> data = jsonDecode(message);
      print('Received from ${client.id}: $data');

      switch (data['type']) {
        case 'fetch_rooms':
          sendRoomsList(client);
          break;

        case 'create':
          createRoom(client, data['name']);
          break;

        case 'join':
          joinRoom(client, data['room']);
          break;

        default:
          sendToClient(client, {
            'type': 'error',
            'message': 'Unknown message type: ${data['type']}',
          });
      }
    } catch (e) {
      print('Error parsing message from ${client.id}: $e');
      sendToClient(client, {
        'type': 'error',
        'message': 'Invalid message format',
      });
    }
  }

  void createRoom(Client client, String? roomName){
    if(roomName == null || roomName.isEmpty){
      sendToClient(client, {
        "type" : "status",
        "message" : "Room name cant be empty",
      });
      return;
    }
    if(rooms.containsKey(roomName)){
      sendToClient(client, {
        "type" : "status",
        "message" : "Room already exists",
      });
      return;
    }
    rooms[roomName] = Room(roomName);
    sendToClient(client, {
      "type": "status",
      "message": "room created sucessufly",
    });

  }

  void joinRoom(Client client, String? roomName){
    if(roomName==null || !rooms.containsKey(roomName)){
      sendToClient(client, {
        "type": "status",
        "message": "room not found",
      });
      return;
    }

    Room room = rooms[roomName]!;

    if(room.clients.length>= room.capacity){
      sendToClient(client, {
        "type": "status",
        "message": "room is full",
      });
      return;
    }

    if(client.currentRoom!=null) leaveRoom(client);

    room.clients.add(client);
    client.currentRoom = roomName;

    sendToClient(client, {
      "type": "status",
      "message": "joined room $roomName"
    });
  }

  void leaveRoom(Client client){
    if(client.currentRoom==null) return;
    Room? room = rooms[client.currentRoom];

    if(room!=null){
      room.clients.remove(client);
    }
    client.currentRoom=null;

  }

  void removeClient(Client client){
    leaveRoom(client);
    clients.remove(client.id);
    try{
      client.socket.close();
    }catch(e){
      print("socket already closed? $e");
    }
  }

  void sendToClient(Client client, Map<String, dynamic> data) {
    try {
      String json = jsonEncode(data);
      client.socket.write('$json\n');
    } catch (e) {
      print('Error sending to client ${client.id}: $e');
    }
  }

  void sendRoomsList(Client client){
    List<Map<String,dynamic>> roomsList=[];
    rooms.forEach((name,room){
      roomsList.add(room.toJson());
    });

    sendToClient(client, {
      "type": "rooms_list",
      "rooms": roomsList,
    });
  }

}

void main() async {
  final server = TcpServerForWidget();
  await server.start(host: '0.0.0.0', port: 1234);

  print('TCP Server is running on port 1234');
  print('Press Ctrl+C to stop.');

  // keep server running
  await ProcessSignal.sigint.watch().first;

  print('\nShutting down server...');
  server.stop();
}