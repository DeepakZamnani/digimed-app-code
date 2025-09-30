import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../services/cloud_translate.dart';

// Main Speech-to-Text Health Checkup Screen
class MinimalHealthCheckupScreen extends StatefulWidget {
  @override
  _MinimalHealthCheckupScreenState createState() =>
      _MinimalHealthCheckupScreenState();
}

class _MinimalHealthCheckupScreenState extends State<MinimalHealthCheckupScreen>
    with TickerProviderStateMixin {
  // Core services
  late stt.SpeechToText _speech;
  late CloudTranslatorService _translator;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // State variables
  bool _isListening = false;
  bool _isProcessing = false;
  String _spokenText = '';
  String _selectedLanguage = 'en';
  String _apiUrl = 'https://digimed-model.onrender.com';

  // Language options
  final Map<String, String> _languages = {
    'en': 'English',
    'hi': 'हिंदी',
    'mr': 'मराठी',
    'gu': 'ગુજરાતી',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'bn': 'বাংলা',
    'ur': 'اردو',
  };

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAnimations();
  }

  void _initializeServices() {
    _speech = stt.SpeechToText();
    const apiKey = 'AIzaSyBvyp_gnutyXIGrTJ4doodRXfP9uqzzSeU';
    _translator = CloudTranslatorService(apiKey);
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _startListening() async {
    await _requestPermissions();

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _stopListening();
        }
      },
      onError:
          (error) => _showError('Speech recognition error: ${error.errorMsg}'),
    );

    if (available) {
      setState(() => _isListening = true);
      _pulseController.repeat(reverse: true);

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _spokenText = result.recognizedWords;
          });
        },
        localeId: _getLocaleId(_selectedLanguage),
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 3),
      );
    } else {
      _showError('Speech recognition not available');
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
    _pulseController.stop();
  }

  String _getLocaleId(String languageCode) {
    final locales = {
      'en': 'en-US',
      'hi': 'hi-IN',
      'mr': 'mr-IN',
      'gu': 'gu-IN',
      'ta': 'ta-IN',
      'te': 'te-IN',
      'bn': 'bn-IN',
      'ur': 'ur-PK',
    };
    return locales[languageCode] ?? 'en-US';
  }

  Future<void> _processHealthCheckup() async {
    if (_spokenText.trim().isEmpty) {
      _showError('Please speak your symptoms first');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      String symptomsInEnglish = _spokenText;

      // Translate to English if needed
      if (_selectedLanguage != 'en') {
        symptomsInEnglish = await _translator.translate(
          _spokenText,
          target: 'en',
          source: _selectedLanguage,
        );
      }

      // Get health predictions
      final response = await http
          .post(
            Uri.parse('$_apiUrl/predict'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'symptoms': symptomsInEnglish, 'top_n': 3}),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => MinimalResultScreen(
                    result: result['data'],
                    originalSymptoms: _spokenText,
                    language: _selectedLanguage,
                    translator: _translator,
                  ),
            ),
          );
        } else {
          _showError(result['error'] ?? 'No predictions available');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Connection error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  void _clearText() {
    setState(() => _spokenText = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AI Health Checkup',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Language Selection
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    isExpanded: true,
                    icon: Icon(Icons.language, color: Colors.blue[600]),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    items:
                        _languages.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLanguage = value!;
                        _spokenText = '';
                      });
                    },
                  ),
                ),
              ),

              Spacer(),

              // Speech-to-Text Interface
              Column(
                children: [
                  // Microphone Button
                  GestureDetector(
                    onTap: _isListening ? _stopListening : _startListening,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isListening ? _pulseAnimation.value : 1.0,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color:
                                  _isListening
                                      ? Colors.red[400]
                                      : Colors.blue[600],
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening
                                          ? Colors.red
                                          : Colors.blue)
                                      .withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 24),

                  // Status Text
                  Text(
                    _isListening
                        ? 'Listening... Speak your symptoms'
                        : _spokenText.isEmpty
                        ? 'Tap microphone to speak'
                        : 'Tap microphone to speak again',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              SizedBox(height: 32),

              // Spoken Text Display
              if (_spokenText.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: 80),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[100]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.record_voice_over,
                            color: Colors.blue[600],
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Your Symptoms',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                          Spacer(),
                          IconButton(
                            onPressed: _clearText,
                            icon: Icon(
                              Icons.clear,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                            constraints: BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        _spokenText,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],

              Spacer(),

              // Process Button
              if (_spokenText.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processHealthCheckup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      shadowColor: Colors.blue.withOpacity(0.3),
                    ),
                    child:
                        _isProcessing
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
                                Icon(
                                  Icons.psychology,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Analyze Health',
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
              ],

              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.cancel();
    super.dispose();
  }
}

// Minimal Results Screen
class MinimalResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final String originalSymptoms;
  final String language;
  final CloudTranslatorService translator;

  const MinimalResultScreen({
    Key? key,
    required this.result,
    required this.originalSymptoms,
    required this.language,
    required this.translator,
  }) : super(key: key);

  @override
  _MinimalResultScreenState createState() => _MinimalResultScreenState();
}

class _MinimalResultScreenState extends State<MinimalResultScreen> {
  Map<String, String> _translations = {};
  bool _isTranslating = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.language != 'en') {
      _translateContent();
    }
  }

  Future<void> _translateContent() async {
    setState(() => _isTranslating = true);

    try {
      final predictions = widget.result['predictions'] as List<dynamic>? ?? [];
      final textsToTranslate = <String>[];
      final keys = <String>[];

      for (int i = 0; i < predictions.length; i++) {
        final prediction = predictions[i];
        keys.add('disease_$i');
        textsToTranslate.add(prediction['disease'] ?? '');

        keys.add('treatment_$i');
        textsToTranslate.add(prediction['treatment'] ?? '');

        keys.add('recommendation_$i');
        textsToTranslate.add(prediction['recommendation'] ?? '');
      }

      if (textsToTranslate.isNotEmpty) {
        final translatedTexts = await widget.translator.translateBatch(
          textsToTranslate,
          target: widget.language,
          source: 'en',
        );

        final translationMap = <String, String>{};
        for (int i = 0; i < keys.length; i++) {
          translationMap[keys[i]] = translatedTexts[i];
        }

        setState(() => _translations = translationMap);
      }
    } catch (e) {
      print('Translation error: $e');
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  String _getTranslatedText(String key, String fallback) {
    return _translations[key] ?? fallback;
  }

  double _getHighestProbability(List<dynamic> predictions) {
    if (predictions.isEmpty) return 0.0;
    double highest = 0.0;
    for (var prediction in predictions) {
      final prob = prediction['probability'] ?? 0.0;
      if (prob > highest) highest = prob;
    }
    return highest * 100;
  }

  Widget _buildRecommendationCard(double probability) {
    String title;
    String description;
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    if (probability < 20) {
      title = 'Self Care & Precautions';
      description =
          'Low probability detected. Focus on general health precautions, rest, and monitor symptoms.';
      backgroundColor = Colors.green[50]!;
      borderColor = Colors.green[200]!;
      textColor = Colors.green[700]!;
      icon = Icons.self_improvement;
    } else if (probability <= 50) {
      title = 'Clinic Visit Recommended';
      description =
          'Moderate probability detected. Schedule a clinic visit for proper examination and guidance.';
      backgroundColor = Colors.orange[50]!;
      borderColor = Colors.orange[200]!;
      textColor = Colors.orange[700]!;
      icon = Icons.local_hospital;
    } else {
      title = 'Immediate Medical Attention';
      description =
          'High probability detected. Seek immediate medical attention from a healthcare professional.';
      backgroundColor = Colors.red[50]!;
      borderColor = Colors.red[200]!;
      textColor = Colors.red[700]!;
      icon = Icons.emergency;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: textColor, size: 32),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(fontSize: 14, color: textColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _saveHealthData() async {
    setState(() => _isSaving = true);

    try {
      final predictions = widget.result['predictions'] as List<dynamic>? ?? [];
      final highestProbability = _getHighestProbability(predictions);

      await FirebaseFirestore.instance.collection('health_checkups').add({
        'symptoms': widget.originalSymptoms,
        'language': widget.language,
        'predictions':
            predictions
                .map(
                  (p) => {
                    'disease': p['disease'],
                    'probability': p['probability'],
                    'treatment': p['treatment'],
                    'recommendation': p['recommendation'],
                  },
                )
                .toList(),
        'highest_probability': highestProbability,
        'analysis': widget.result['analysis'],
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': 'current_user_id', // Replace with actual user ID
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Health data saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _shareHealthData() async {
    try {
      final predictions = widget.result['predictions'] as List<dynamic>? ?? [];
      final highestProbability = _getHighestProbability(predictions);

      String shareText = 'Health Analysis Report\n\n';
      shareText += 'Symptoms: ${widget.originalSymptoms}\n\n';

      if (predictions.isNotEmpty) {
        final topPrediction = predictions.first;
        shareText += 'Top Prediction:\n';
        shareText += 'Condition: ${topPrediction['disease']}\n';
        shareText +=
            'Probability: ${(topPrediction['probability'] * 100).toStringAsFixed(1)}%\n\n';
        shareText += 'Treatment: ${topPrediction['treatment']}\n\n';
        shareText += 'Recommendation: ${topPrediction['recommendation']}\n\n';
      }

      shareText += 'Generated by AI Health Checkup App\n';
      shareText +=
          'Note: This is not a medical diagnosis. Consult a healthcare professional.';

      await Share.share(shareText, subject: 'Health Analysis Report');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _bookAppointment() async {
    try {
      final predictions = widget.result['predictions'] as List<dynamic>? ?? [];
      final topPrediction = predictions.isNotEmpty ? predictions.first : null;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.blue[600]),
                  SizedBox(height: 16),
                  Text('Booking appointment...'),
                ],
              ),
            ),
      );

      // Create appointment data
      final appointmentData = {
        'patient_id': 'current_user_id', // Replace with actual user ID
        'patient_name': 'Patient Name', // Get from user profile
        'patient_phone': '+1234567890', // Get from user profile
        'symptoms': widget.originalSymptoms,
        'predicted_condition':
            topPrediction?['disease'] ?? 'General consultation',
        'probability': topPrediction?['probability'] ?? 0.0,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
        'scheduled_date': null,
        'doctor_id': null,
      };

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text('Appointment Booked'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Your appointment has been scheduled successfully.'),
                  SizedBox(height: 12),
                  Text(
                    'Appointment ID: ${docRef.id.substring(0, 8).toUpperCase()}',
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
      );
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to book appointment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final predictions = widget.result['predictions'] as List<dynamic>? ?? [];
    final analysis = widget.result['analysis'] as Map<String, dynamic>? ?? {};
    final matchPercentage = analysis['match_percentage'] ?? 0;
    final highestProbability = _getHighestProbability(predictions);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Health Analysis',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isTranslating
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.blue[600]),
                    SizedBox(height: 16),
                    Text(
                      'Translating results...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Symptoms Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Symptoms',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[800],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            widget.originalSymptoms,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[700],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Recommendation based on probability
                    _buildRecommendationCard(highestProbability),

                    SizedBox(height: 20),

                    // Results
                    if (predictions.isNotEmpty) ...[
                      // Show top prediction only
                      ...predictions.take(1).map((prediction) {
                        final index = predictions.indexOf(prediction);
                        return Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Disease name
                              Text(
                                _getTranslatedText(
                                  'disease_$index',
                                  prediction['disease'] ?? '',
                                ).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 16),

                              // Probability
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Probability: ${(prediction['probability'] * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),

                              SizedBox(height: 20),

                              // Treatment
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Treatment',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      _getTranslatedText(
                                        'treatment_$index',
                                        prediction['treatment'] ?? '',
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 16),

                              // Recommendation
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recommendation',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber[800],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      _getTranslatedText(
                                        'recommendation_$index',
                                        prediction['recommendation'] ?? '',
                                      ),
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
                        );
                      }).toList(),
                    ],

                    SizedBox(height: 24),

                    // Action buttons based on probability
                    if (highestProbability >= 20) ...[
                      Container(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _bookAppointment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                highestProbability > 50
                                    ? Colors.red[600]
                                    : Colors.orange[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Book Appointment',
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
                      SizedBox(height: 16),
                    ],

                    // Save and Share buttons row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveHealthData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child:
                                  _isSaving
                                      ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.save,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Save Data',
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
                        SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _bookAppointment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Book Appointment',
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

                    SizedBox(height: 24),

                    // Disclaimer
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.red[600],
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This is not a medical diagnosis. Consult a healthcare professional for proper medical advice.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // New Assessment Button
                    Container(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.blue[600]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'New Assessment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
