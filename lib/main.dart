import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:share/share.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  static List<DiscoveredDevice> discoveredDevices = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlexoSkiBootss',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Devices'),
      
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  late Stream<DiscoveredDevice> _scanResults;

  @override
  void initState() {
    super.initState();
    final status = Permission.locationWhenInUse.status;
    if (status.isGranted == false) {
      Permission.locationWhenInUse.request();
    } else {
      print("Permission granted");
    }

    final storage = Permission.storage.status;
    final bluetooth = Permission.bluetooth.status;
    final location = Permission.location.status;
    final loc = Permission.locationAlways.status;
    final loc2 = Permission.locationWhenInUse.status;
    

    if (loc2.isGranted == false) {
      Permission.locationWhenInUse.request();
    } else {
      print("Permission granted");
    }

    if (loc.isGranted == false) {
      Permission.locationAlways.request();
    } else {
      print("Permission granted");
    }

    if (storage.isGranted == false) {
      Permission.storage.request();
    } else {
      print("Permission granted");
    }

    if (bluetooth.isGranted == false) {
      Permission.bluetooth.request();
    } else {
      print("Permission granted");
    }

    if (location.isGranted == false) {
      Permission.location.request();
    } else {
      print("Permission granted");
    }


    _scanResults = _ble.scanForDevices(
      withServices: [],
    );
    // print("a");
    // final l2 = Permission.loca
    _scanResults.listen((device) {
      setState(() {
        // print("b");

        if (!MyApp.discoveredDevices.any((element) => element.id == device.id) && device.name != null && device.name.contains("FlexoSkiBoots BLE")) {
          MyApp.discoveredDevices.add(device);
          // print("b");
        }
      });
    });
  }

  Future<void> _showConnectDialog(DiscoveredDevice device) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Conectar a ${device.name ?? 'Dispositivo'}'),
          content: Text('¿Estás seguro de que deseas conectarte a este dispositivo?'),
          actions: <Widget>[
            TextButton(
              child: Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Sí'),
            
              onPressed: () {
                Navigator.of(context).pop();
                _connectToDevice(device);
              },
              
            ),
            
          ],
        );
      },
    );
  }

  void _connectToDevice(DiscoveredDevice device) {
    // Aquí puedes implementar la lógica para conectar al dispositivo seleccionado.
    // Por ejemplo:
    // _ble.connectToDevice(id: device.id);

    // Navegar a la página de conexión y pasar el dispositivo seleccionado como argumento.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ConnectionPage(device: device)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: ListView.builder(
          itemCount: MyApp.discoveredDevices.length,
          itemBuilder: (context, index) {
            final device = MyApp.discoveredDevices[index];
            return Container(
              margin: EdgeInsets.all(8.0), // Define el margen deseado aquí
              child: Card(
                child: ListTile(
                  title: Text("Id: " + device.id),
                  subtitle: Text("Name: " + (device.name ?? 'Unknown')),
                  onTap: () {
                    _showConnectDialog(device);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ConnectionPage extends StatefulWidget {
  final DiscoveredDevice device;

  ConnectionPage({required this.device});

  @override
  _ConnectionPageState createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  bool _isRecording = false;
  int _counter = 0;
  late Timer _timer;
  late StreamSubscription<DiscoveredDevice> _scanSubscription;
  String deviceId = "";
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  
  // to send the start recording command to the device, you need to know the UUID of the characteristic that allows you to send commands to the device.
  String BOARD_REGISTER_CHARACTERISTIC_UUID = "0000ff01-0000-1000-8000-00805f9b34fb";
  // to receive the data from the device, you need to know the UUID of the characteristic that allows you to receive data from the device.
  String BOARD_CONNECTION_CHARACTERISTIC_UUID = "0000ee01-0000-1000-8000-00805f9b34fb";
  
  void _startRecording() async {
    _scanSubscription = _ble.scanForDevices(withServices: []).listen((device) async {
      if (device.name != null && device.name.contains("FlexoSkiBoots BLE")) {
        deviceId = device.id;
      }
    });

    if (deviceId.isEmpty) {
      return;
    }
    // discover all services that has the characteristics that we need, prevent services != null
    await _ble.discoverAllServices(deviceId);
    final services = await _ble.getDiscoveredServices(deviceId);
    print(services);
    var serviceId;
    for (var service in services) {
      if (service.characteristics != null) {
        for (var characteristic in service.characteristics!) {
          if (characteristic.id == Uuid.parse(BOARD_REGISTER_CHARACTERISTIC_UUID)) {
            serviceId = service.id;
            print("Service ID: $serviceId");
          }
        }
      }
    }
    // Get the id of the connected device.

    QualifiedCharacteristic connection_characteristic = QualifiedCharacteristic(
      serviceId: serviceId, 
      characteristicId: Uuid.parse(BOARD_REGISTER_CHARACTERISTIC_UUID),
      deviceId: deviceId
    );
    
    print("Sending start recording command to device");
    // send a 1 to the device to start recording
    await _ble.writeCharacteristicWithoutResponse(connection_characteristic, value: [1]);
    _isRecording = true;

    print("Start recording command sent");
    // now read the data from the device, store it into a vector and when user click stop store the data into a file
    
  for (var service in services) {
      if (service.characteristics != null) {
        for (var characteristic in service.characteristics!) {
          if (characteristic.id == Uuid.parse(BOARD_CONNECTION_CHARACTERISTIC_UUID)) {
            serviceId = service.id;
            print("Service ID: $serviceId");
          }
        }
      }
  }

    QualifiedCharacteristic register_characteristic = QualifiedCharacteristic(
      serviceId: serviceId,
      characteristicId: Uuid.parse(BOARD_CONNECTION_CHARACTERISTIC_UUID),
      deviceId: deviceId
    );

    // check if data folder exists, if not create it
    var appDocumentDir = await getApplicationDocumentsDirectory();
    final dataDir = Directory('${appDocumentDir.path}/data');
    if (!(await dataDir.exists())) {
      await dataDir.create();
    }

    appDocumentDir = await getApplicationDocumentsDirectory();
    final fileName = '${deviceId}-${DateTime.now().millisecondsSinceEpoch}.dat';
    final file = File('${appDocumentDir.path}/data/$fileName');
    print('File path: ${file.path}');
    await file.create();

    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      List<int> value = await _ble.readCharacteristic(register_characteristic);
      print(value);
      setState(() {
        _counter++;
      });
      
      // Save the data to a file
      await file.writeAsBytes(value, mode: FileMode.append);


    });
  }

  



  void _stopRecording() async {

    if (deviceId.isEmpty) {
      return;
    }

    await _scanSubscription.cancel();
    _timer.cancel();

    setState(() {
      _isRecording = false;
      _counter = 0;
    });

    print("Stop recording command sent");

    await _ble.discoverAllServices(deviceId);
      final services = await _ble.getDiscoveredServices(deviceId);
      print(services);
      var serviceId;
      for (var service in services) {
        if (service.characteristics != null) {
          for (var characteristic in service.characteristics!) {
            if (characteristic.id == Uuid.parse(BOARD_REGISTER_CHARACTERISTIC_UUID)) {
              serviceId = service.id;
              print("Service ID: $serviceId");
            }
          }
        }
      }

    // send a 0 to the device to stop recording
    await _ble.writeCharacteristicWithoutResponse(QualifiedCharacteristic(
      serviceId: serviceId,
      characteristicId: Uuid.parse(BOARD_REGISTER_CHARACTERISTIC_UUID),
      deviceId: deviceId
    ), value: [0]);

    print("Stop recording command sent");
    
  }

  



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name ?? 'Dispositivo Desconocido'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'devices':
                  // Ve a la página de dispositivos
                  Navigator.pop(context);
                  break;
                case 'record':
                  // Lógica para la opción "Record"
                  break;
                case 'historical':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HistoricalPage(deviceName: widget.device.id ?? 'Dispositivo Desconocido') ),
                  );
                  break;

              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'devices',
                child: Text('Devices'),
              ),
              PopupMenuItem(
                value: 'record',
                child: Text('Record'),
              ),
              PopupMenuItem(
                value: 'historical',
                child: Text('Historical'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Conectado a ${widget.device.name ?? 'Dispositivo Desconocido'}'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_isRecording) {
                  _stopRecording();
                } else {
                  _startRecording();
                }
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (_isRecording) {
                    return Colors.red;
                  } else {
                    return Colors.green;
                  }
                }),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
              child: Text(
                _isRecording ? 'Detener Grabación' : 'Iniciar Grabación',
                style: TextStyle(
                  color: Colors.white, // Cambiar el color del texto a blanco
                ),
              ),
            ),

            SizedBox(height: 20),
            Text('Tiempo grabado: $_counter segundos'),
          ],
        ),
      ),
    );
  }
}

class HistoricalPage extends StatelessWidget {
  final String deviceName;
  HistoricalPage({required this.deviceName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial'),
      ),
      body: FutureBuilder<List<File>>(
        future: _getFilesInDataDirectory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No hay archivos disponibles'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                File file = snapshot.data![index];
                return ListTile(
                  title: Text(file.path.split('/').last),
                  onTap: () => _shareFile(context, file),
                );
              },
            );
          }
        },
      ),
    );
  }

  Future<List<File>> _getFilesInDataDirectory() async {
    Directory directory = await getApplicationDocumentsDirectory();
    Directory dataDir = Directory('${directory.path}/data');
    if (await dataDir.exists()) {
      var files =  dataDir.listSync().whereType<File>().toList();
      // Return only the files that contain the name of the device in the filename
      return files.where((file) => file.path.contains(deviceName)).toList();
    } else {
      return [];
    }
  }

  void _shareFile(BuildContext context, File file) {
    Share.shareFiles([file.path], text: 'Compartir archivo ${file.path.split('/').last}');
  }
}


class PermissionPage extends StatefulWidget {
  @override
  _PermissionPageState createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    setState(() {
      _permissionStatus = status;
    });
  }

  Future<void> _requestPermission() async {
    PermissionStatus status = await Permission.locationWhenInUse.request();
    setState(() {
      _permissionStatus = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Permission Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Permission Status: $_permissionStatus',
              style: TextStyle(fontSize: 18.0),
            ),
            SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () {
                _requestPermission();
              },
              child: Text('Request Permission'),
            ),
          ],
        ),
      ),
    );
  }
}