import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ERA Timesheet App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkLoginAndCompany();
  }

  Future<void> _checkLoginAndCompany() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? selectedCompany = prefs.getString('selectedCompany');
    String? userEmail = prefs.getString('userEmail');

    // Simulate a delay to show the loading bar
    await Future.delayed(Duration(seconds: 2));

    if (selectedCompany != null && userEmail != null) {
      // If the company and email are selected, go directly to the QRCode screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QRCodePage(companyName: selectedCompany, userEmail: userEmail),
        ),
      );
    } else {
      // Otherwise show the login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Insert your logo here
            Image.asset(
              'assets/logo.png', // Ensure the image path is correct
              height: 100, // Adjust the logo height
            ),
            SizedBox(height: 20), // Space between logo and loading bar
            CircularProgressIndicator(), // Loading indicator
            SizedBox(height: 20), // Space below the loading bar
            Text('Caricamento...'), // Loading message
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> _login(BuildContext context) async {
    final email = emailController.text;
    final password = passwordController.text;

    final response = await http.post(
      Uri.parse('https://apitimesheet.era-management.com/login'),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userEmail', email); // Save email
      String? selectedCompany = prefs.getString('selectedCompany');

      if (selectedCompany == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SettingsPage(userEmail: email)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => QRCodePage(companyName: selectedCompany, userEmail: email)),
        );
      }
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login fallito!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login'), centerTitle: true), // Centro il titolo dell'AppBar
      body: Center( // Utilizzo di Center per centrare tutto
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _login(context),
                child: Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final String userEmail;

  SettingsPage({required this.userEmail});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? selectedCompany;
  List<Map<String, dynamic>> companies = [];

  Future<void> _loadCompanies() async {
    final response =
        await http.get(Uri.parse('https://apitimesheet.era-management.com/companies'));

    if (response.statusCode == 200) {
      setState(() {
        companies = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento ditte')));
    }
  }

  Future<void> _saveSettings() async {
    if (selectedCompany != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String companyName = companies
          .firstWhere((company) => company['id'].toString() == selectedCompany)['name'];
      await prefs.setString('selectedCompany', companyName);
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => QRCodePage(companyName: companyName, userEmail: widget.userEmail)),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Seleziona una ditta')));
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('selectedCompany');
    await prefs.remove('userEmail'); // Remove email
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings'), centerTitle: true), // Centro il titolo dell'AppBar
      body: Center( // Utilizzo di Center per centrare tutto
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Utente collegato: ${widget.userEmail}'), // Show connected user email
            DropdownButton<String>(
              value: selectedCompany,
              hint: Text('Seleziona la tua ditta'),
              onChanged: (newValue) {
                setState(() {
                  selectedCompany = newValue;
                });
              },
              items: companies.map((company) {
                return DropdownMenuItem(
                  child: Text(company['name']),
                  value: company['id'].toString(),
                );
              }).toList(),
            ),
            ElevatedButton(
              onPressed: _saveSettings,
              child: Text('Salva'),
            ),
            SizedBox(height: 20), // Space between buttons
            ElevatedButton(
              onPressed: _logout,
              child: Text('Disconnetti'),
            ),
          ],
        ),
      ),
    );
  }
}

class QRCodePage extends StatefulWidget {
  final String companyName;
  final String userEmail; // Add email as a parameter

  QRCodePage({required this.companyName, required this.userEmail});

  @override
  _QRCodePageState createState() => _QRCodePageState();
}

class _QRCodePageState extends State<QRCodePage> {
  String currentDateTime = '';
  String? scanResult;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WakelockPlus.enable();
  }

  void _startTimer() {
    setState(() {
      currentDateTime = DateFormat('dd/MM/yyyy – kk:mm:ss').format(DateTime.now());
    });
    Future.delayed(Duration(seconds: 1), _startTimer);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _submitCheckIn(String qrCodeData) async {
    final response = await http.post(
      String idUser = qrCodeData.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      Uri.parse('https://apitimesheet.era-management.com/timesheet'),
      body: jsonEncode({
        'id_user': idUser,
        'activity': 'in',
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Check-In effettuato')));
      _resetScanner();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Errore nel Check-In')));
    }
  }

  Future<void> _submitCheckOut(String qrCodeData) async {
    String idUser = qrCodeData.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final response = await http.post(
      Uri.parse('https://apitimesheet.era-management.com/timesheet'),
      body: jsonEncode({
        'id_user': idUser,
        'activity': 'out',
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Check-Out effettuato')));
      _resetScanner();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Errore nel Check-Out')));
    }
  }

  void _resetScanner() {
    setState(() {
      scanResult = null;
    });
  }

  Future<void> _scanQRCode() async {
    try {
      final result = await FlutterBarcodeScanner.scanBarcode(
          "#ff6666", "Annulla", false, ScanMode.QR);
      if (result != '-1') {
        setState(() {
          scanResult = result;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Errore nella scansione')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Code Scanner'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(userEmail: widget.userEmail),
                ),
              );
            },
          ),
        ],
        centerTitle: true, // Centro il titolo dell'AppBar
      ),
      body: Center( // Utilizzo di Center per centrare tutto
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ditta: ${widget.companyName}'), // Display selected company
              Text('Utente: ${widget.userEmail}'), // Display user email
              Text('Data e ora corrente: $currentDateTime'), // Show current time
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _scanQRCode,
                child: Text('Scansiona QR Code'),
              ),
              SizedBox(height: 20),
              if (scanResult != null) ...[
                Text('Risultato scansione: $scanResult'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, // Centro i bottoni
                  children: [
                    ElevatedButton(
                      onPressed: () => _submitCheckIn(scanResult!),
                      child: Text('Check-In'),
                    ),
                    SizedBox(width: 20), // Spazio tra i bottoni
                    ElevatedButton(
                      onPressed: () => _submitCheckOut(scanResult!),
                      child: Text('Check-Out'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}
