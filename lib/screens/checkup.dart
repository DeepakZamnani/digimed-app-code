import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MedicalLLMApp extends StatelessWidget {
  const MedicalLLMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical LLM Helper',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SuggestionScreen(),
    );
  }
}

class SuggestionScreen extends StatefulWidget {
  const SuggestionScreen({super.key});

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _sexController = TextEditingController();
  final TextEditingController _complaintController = TextEditingController();
  final TextEditingController _historyController = TextEditingController();

  String? _result;
  bool _loading = false;

  Future<void> _getSuggestion() async {
    setState(() {
      _loading = true;
      _result = null;
    });

    final url = Uri.parse(
      "http://127.0.0.1:5000/suggest",
    ); // change to your backend host/port
    final body = {
      "patient": {
        "name": _nameController.text,
        "age": int.tryParse(_ageController.text) ?? 0,
        "sex": _sexController.text,
      },
      "chief_complaint": _complaintController.text,
      "history": _historyController.text,
      "vitals": {},
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          _result = json["suggestion"] ?? "No suggestion returned.";
        });
      } else {
        setState(() {
          _result = "Error: ${response.statusCode} ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _result = "Failed to connect: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medical LLM Helper")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Patient Name"),
              ),
              TextField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: "Age"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _sexController,
                decoration: const InputDecoration(labelText: "Sex"),
              ),
              TextField(
                controller: _complaintController,
                decoration: const InputDecoration(labelText: "Chief Complaint"),
              ),
              TextField(
                controller: _historyController,
                decoration: const InputDecoration(labelText: "History"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _getSuggestion,
                child:
                    _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Get Suggestion"),
              ),
              const SizedBox(height: 20),
              if (_result != null)
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_result!, style: const TextStyle(fontSize: 16)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
