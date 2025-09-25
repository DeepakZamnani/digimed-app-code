import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
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

  bool _allProbabilitiesLow(List<dynamic> predictions) {
    if (predictions.isEmpty) return true;
    for (var prediction in predictions) {
      final prob = prediction['probability'] ?? 0.0;
      if ((prob * 100) >= 50) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final predictions = widget.result['predictions'] as List<dynamic>? ?? [];
    final analysis = widget.result['analysis'] as Map<String, dynamic>? ?? {};
    final matchPercentage = analysis['match_percentage'] ?? 0;

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

                    // Results
                    if (matchPercentage < 50 &&
                        _allProbabilitiesLow(predictions)) ...[
                      // Low confidence result
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.health_and_safety,
                              color: Colors.green[600],
                              size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'General Health Check',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No specific conditions detected. Consider consulting a doctor for routine checkup.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ] else if (predictions.isNotEmpty) ...[
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
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'New Assessment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
