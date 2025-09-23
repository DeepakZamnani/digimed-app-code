import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_translate/flutter_translate.dart';

// First Screen - Symptom Input with Enhanced Debugging
class SymptomInputScreen extends StatefulWidget {
  @override
  _SymptomInputScreenState createState() => _SymptomInputScreenState();
}

class _SymptomInputScreenState extends State<SymptomInputScreen> {
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _topNController = TextEditingController(
    text: '5',
  );
  bool _isLoading = false;
  String _apiUrl = 'https://digimed-model.onrender.com';
  List<String> _availableSymptoms = [];
  List<String> _recognizedSymptoms = [];
  List<String> _unrecognizedSymptoms = [];
  String _debugInfo = ''; // Add debug information display

  List<String> _commonSymptoms = [
    'fever',
    'cough',
    'headache',
    'fatigue',
    'nausea',
    'diarrhea',
    'chest pain',
    'shortness of breath',
    'dizziness',
    'muscle pain',
    'sore throat',
    'runny nose',
    'stomach pain',
    'vomiting',
    'joint pain',
    'skin rash',
  ];

  @override
  void initState() {
    super.initState();
    _testApiConnection();
    _fetchAvailableSymptoms();
    _symptomsController.addListener(_validateSymptoms);
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _debugInfo = 'Testing API connection...';
    });

    try {
      print('Testing connection to: $_apiUrl');
      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 10));

      print('Connection test - Status: ${response.statusCode}');
      print('Connection test - Body: ${response.body}');

      setState(() {
        _debugInfo = 'API Status: ${response.statusCode} - ${response.body}';
      });
    } catch (e) {
      print('Connection test failed: $e');
      setState(() {
        _debugInfo = 'Connection failed: $e';
      });
    }
  }

  Future<void> _fetchAvailableSymptoms() async {
    try {
      print('Fetching symptoms from: $_apiUrl/symptoms');
      final response = await http
          .get(
            Uri.parse('$_apiUrl/symptoms'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 15));

      print('Symptoms response status: ${response.statusCode}');
      print('Symptoms response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('Parsed symptoms result: $result');

        if (result['success'] == true) {
          setState(() {
            _availableSymptoms = List<String>.from(result['data']['symptoms']);
            _debugInfo += '\nSymptoms loaded: ${_availableSymptoms.length}';
          });
          print('Available symptoms loaded: ${_availableSymptoms.length}');
        } else {
          setState(() {
            _debugInfo += '\nSymptoms API returned success=false';
          });
        }
      } else {
        setState(() {
          _debugInfo += '\nSymptoms API error: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('Failed to fetch symptoms: $e');
      setState(() {
        _debugInfo += '\nSymptoms fetch error: $e';
      });
    }
  }

  void _validateSymptoms() {
    String text = _symptomsController.text;
    if (text.isEmpty) {
      setState(() {
        _recognizedSymptoms.clear();
        _unrecognizedSymptoms.clear();
      });
      return;
    }

    List<String> inputSymptoms =
        text
            .split(',')
            .map((s) => s.trim().toLowerCase())
            .where((s) => s.isNotEmpty)
            .toList();

    List<String> recognized = [];
    List<String> unrecognized = [];

    for (String symptom in inputSymptoms) {
      bool found = false;

      if (_availableSymptoms.any((s) => s.toLowerCase() == symptom)) {
        recognized.add(symptom);
        found = true;
      } else {
        for (String availableSymptom in _availableSymptoms) {
          if ((symptom.length > 2 &&
                  availableSymptom.toLowerCase().contains(symptom)) ||
              (symptom.length > 2 &&
                  symptom.contains(availableSymptom.toLowerCase()))) {
            recognized.add(symptom);
            found = true;
            break;
          }
        }
      }

      if (!found) {
        unrecognized.add(symptom);
      }
    }

    setState(() {
      _recognizedSymptoms = recognized;
      _unrecognizedSymptoms = unrecognized;
    });
  }

  void _addSymptom(String symptom) {
    String currentText = _symptomsController.text.trim();
    if (currentText.isEmpty) {
      _symptomsController.text = symptom;
    } else {
      if (!currentText.toLowerCase().contains(symptom.toLowerCase())) {
        _symptomsController.text = '$currentText, $symptom';
      }
    }
  }

  Future<void> _predictDisease() async {
    if (_symptomsController.text.trim().isEmpty) {
      _showErrorDialog(translate('quick_checkup.describe_symptoms'));
      return;
    }

    setState(() {
      _isLoading = true;
      _debugInfo += '\nStarting prediction...';
    });

    try {
      final requestData = {
        'symptoms': _symptomsController.text.trim(),
        'top_n': int.tryParse(_topNController.text) ?? 5,
      };

      print('Sending prediction request to: $_apiUrl/predict');
      print('Request data: $requestData');

      final response = await http
          .post(
            Uri.parse('$_apiUrl/predict'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(requestData),
          )
          .timeout(Duration(seconds: 30));

      print('Prediction response status: ${response.statusCode}');
      print('Prediction response headers: ${response.headers}');
      print('Prediction response body: ${response.body}');

      setState(() {
        _debugInfo += '\nPrediction status: ${response.statusCode}';
      });

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('Parsed prediction result: $result');

        setState(() {
          _debugInfo += '\nPrediction success: ${result['success']}';
        });

        if (result['success'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ResultScreen(
                    result: result['data'],
                    symptoms: _symptomsController.text.trim(),
                  ),
            ),
          );
        } else {
          _showErrorDialog(
            result['error'] ?? translate('quick_checkup.no_predictions'),
          );
        }
      } else {
        _showErrorDialog(
          '${translate('quick_checkup.error')} ${response.statusCode}\nResponse: ${response.body}',
        );
      }
    } catch (e) {
      print('Prediction error: $e');
      _showErrorDialog(
        'Connection error: $e\n\nPlease check:\n- Internet connection\n- API server status\n- Firewall settings',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(translate('quick_checkup.debug_information')),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    translate('quick_checkup.error'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message),
                  SizedBox(height: 16),
                  Text(
                    translate('quick_checkup.debug_info'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_debugInfo, style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  translate('quick_checkup.ok'),
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: _testApiConnection,
                child: Text(
                  translate('quick_checkup.retry_connection'),
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          translate('quick_checkup.debug_mode'),
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Debug Info Card
            if (_debugInfo.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bug_report,
                          color: Colors.amber[700],
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          translate('quick_checkup.debug_information'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _debugInfo,
                      style: TextStyle(fontSize: 12, color: Colors.amber[700]),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],

            // Header Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.favorite_border,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              translate('quick_checkup.ai_health_assessment'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              translate(
                                'quick_checkup.api_url',
                              ).replaceAll('\$_apiUrl', _apiUrl),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              translate(
                                'quick_checkup.available_symptoms',
                              ).replaceAll(
                                '\${_availableSymptoms.length}',
                                '${_availableSymptoms.length}',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Symptoms Input Card
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('quick_checkup.describe_symptoms'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _symptomsController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'Enter symptoms separated by commas (e.g., fever, cough, headache)',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),

                  // Symptom Validation Feedback
                  if (_symptomsController.text.isNotEmpty) ...[
                    SizedBox(height: 12),
                    if (_recognizedSymptoms.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            translate(
                              'quick_checkup.recognized_symptoms',
                            ).replaceAll(
                              '\${_recognizedSymptoms.length}',
                              '${_recognizedSymptoms.length}',
                            ),
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children:
                            _recognizedSymptoms
                                .map(
                                  (symptom) => Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      symptom,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                    if (_unrecognizedSymptoms.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Text(
                            translate(
                              'quick_checkup.not_recognized_symptoms',
                            ).replaceAll(
                              '\${_unrecognizedSymptoms.length}',
                              '${_unrecognizedSymptoms.length}',
                            ),
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),

            SizedBox(height: 20),

            // Test Buttons Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testApiConnection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      translate('quick_checkup.test_connection'),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _fetchAvailableSymptoms,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      translate('quick_checkup.reload_symptoms'),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Common Symptoms Card (shortened for debug version)
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('quick_checkup.quick_test_symptoms'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _commonSymptoms.take(6).map((symptom) {
                          bool isSelected = _symptomsController.text
                              .toLowerCase()
                              .contains(symptom.toLowerCase());
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _addSymptom(symptom),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? Colors.blue[50]
                                          : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? Colors.blue[300]!
                                            : Colors.grey[300]!,
                                  ),
                                ),
                                child: Text(
                                  symptom,
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.blue[700]
                                            : Colors.grey[700],
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Settings Card
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.tune, color: Colors.purple, size: 20),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate('quick_checkup.num_predictions'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          translate('quick_checkup.choose_diseases'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 70,
                    child: TextField(
                      controller: _topNController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Predict Button
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _predictDisease,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child:
                    _isLoading
                        ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              translate('quick_checkup.get_health_assessment'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    _topNController.dispose();
    super.dispose();
  }
}

// Second Screen - Results with Enhanced Design
class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final String symptoms;

  const ResultScreen({Key? key, required this.result, required this.symptoms})
    : super(key: key);

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red[600]!;
      case 'high':
        return Colors.orange[600]!;
      case 'moderate':
        return Colors.yellow[700]!;
      case 'low':
        return Colors.green[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.warning;
      case 'high':
        return Icons.priority_high;
      case 'moderate':
        return Icons.info;
      case 'low':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  // Helper method to check if all probabilities are less than 50%
  bool _allProbabilitiesLow(List<dynamic> predictions) {
    if (predictions.isEmpty) return true;

    for (var prediction in predictions) {
      final prob = prediction['probability'] ?? 0.0;
      if ((prob * 100) >= 50) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final predictions = result['predictions'] as List<dynamic>? ?? [];
    final analysis = result['analysis'] as Map<String, dynamic>? ?? {};
    final matchPercentage = analysis['match_percentage'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          translate('quick_checkup.health_results'),
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Analysis Summary Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[50]!, Colors.blue[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.analytics,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              translate('quick_checkup.analysis_summary'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            Text(
                              translate('quick_checkup.based_on_symptoms'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Symptoms Provided',
                          '${analysis['symptoms_provided'] ?? 0}',
                          Icons.list,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Recognized',
                          '${analysis['symptoms_recognized'] ?? 0}',
                          Icons.check_circle,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Match Rate',
                          '${matchPercentage}%',
                          Icons.analytics,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate('quick_checkup.your_symptoms'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          symptoms,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Check if both match percentage and all probabilities are less than 50%
            if (matchPercentage < 50 && _allProbabilitiesLow(predictions)) ...[
              // Show ONLY "Basic Checkup" - NO disease predictions at all
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[50]!, Colors.green[100]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Icon(
                        Icons.health_and_safety,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      translate('quick_checkup.basic_checkup'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      translate('quick_checkup.no_disease_detected'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.green[700],
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                translate('quick_checkup.assessment_result'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            translate(
                              'quick_checkup.low_match_message',
                            ).replaceAll(
                              '\${matchPercentage}',
                              '$matchPercentage',
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[700],
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: Colors.blue[600],
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    translate('quick_checkup.recommendation'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (predictions.isEmpty) ...[
              // Show no predictions available
              Center(
                child: Container(
                  padding: EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        translate('quick_checkup.no_predictions'),
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Show predictions (match percentage >= 50%)
              Text(
                translate('quick_checkup.possible_conditions'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                translate('quick_checkup.ai_predictions'),
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              SizedBox(height: 20),

              // Predictions List
              ...predictions.asMap().entries.map((entry) {
                final index = entry.key;
                final prediction = entry.value as Map<String, dynamic>;

                return Container(
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        // Could add detailed view here
                      },
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with rank and disease name
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color:
                                        index == 0
                                            ? Colors.blue[600]
                                            : Colors.grey[400],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (prediction['disease'] as String)
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            _getSeverityIcon(
                                              prediction['severity'] ?? '',
                                            ),
                                            color: _getSeverityColor(
                                              prediction['severity'] ?? '',
                                            ),
                                            size: 16,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            prediction['severity'] ?? 'Unknown',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _getSeverityColor(
                                                prediction['severity'] ?? '',
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                              ],
                            ),

                            SizedBox(height: 20),

                            // Metrics Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    'Probability',
                                    '${(prediction['probability'] * 100).toStringAsFixed(1)}%',
                                    Colors.blue,
                                    Icons.trending_up,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetricCard(
                                    'Confidence',
                                    prediction['confidence'] ?? 'Unknown',
                                    Colors.green,
                                    Icons.verified,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetricCard(
                                    'Risk Level',
                                    '${prediction['risk_percentage']}%',
                                    _getSeverityColor(
                                      prediction['severity'] ?? '',
                                    ),
                                    Icons.warning_amber,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 20),

                            // Doctor and Treatment Section
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.local_hospital,
                                          color: Colors.blue[600],
                                          size: 18,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              translate(
                                                'quick_checkup.recommended_doctor',
                                              ),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              prediction['recommended_doctor'] ??
                                                  'General Practitioner',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.medication,
                                          color: Colors.green[600],
                                          size: 18,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              translate(
                                                'quick_checkup.suggested_treatment',
                                              ),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              prediction['treatment'] ??
                                                  'Consult doctor',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 16),

                            // Recommendation
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: Colors.amber[700],
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          translate(
                                            'quick_checkup.medical_recommendation',
                                          ),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber[800],
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          prediction['recommendation'] ??
                                              'Consult a healthcare professional',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.amber[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],

            SizedBox(height: 32),

            // Disclaimer Card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[600], size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate('quick_checkup.disclaimer'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          translate('quick_checkup.ai_disclaimer'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            translate('quick_checkup.new_assessment'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Could add functionality to share results or book appointment
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (matchPercentage < 50 &&
                                    _allProbabilitiesLow(predictions))
                                ? Colors.blue[600]
                                : Colors.green[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            (matchPercentage < 50 &&
                                    _allProbabilitiesLow(predictions))
                                ? Icons.health_and_safety
                                : Icons.calendar_today,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            (matchPercentage < 50 &&
                                    _allProbabilitiesLow(predictions))
                                ? 'General Checkup'
                                : 'Book Appointment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue[700], size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.blue[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
