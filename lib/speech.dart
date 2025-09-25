import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechModule {
  FlutterTts flutterTts = FlutterTts();
  String textToSpeak = '';
  bool isSpeaking = false;
  double speechRate = 0.5;
  double speechVolume = 0.8;
  double speechPitch = 1.0;
  String selectedLanguage = 'en-US';

  // Speech-to-Text
  SpeechToText speechToText = SpeechToText();
  bool speechEnabled = false;
  bool isListening = false;
  String recognizedWords = '';
  String selectedLocale = 'en_US';

  final TextEditingController textController = TextEditingController();

  @override
  void initState() {
    initTts();
    initStt();
  }

  // Initialize Text-to-Speech
  Future<void> initTts() async {
    await flutterTts.setLanguage(selectedLanguage);
    await flutterTts.setSpeechRate(speechRate);
    await flutterTts.setVolume(speechVolume);
    await flutterTts.setPitch(speechPitch);

    flutterTts.setStartHandler(() {
      isSpeaking = true;
    });

    flutterTts.setCompletionHandler(() {
      isSpeaking = false;
    });

    flutterTts.setErrorHandler((msg) {
      isSpeaking = false;
      print("TTS Error: $msg");
    });
  }

  // Initialize Speech-to-Text
  Future<void> initStt() async {
    speechEnabled = await speechToText.initialize(
      onError: (error) => print('STT Error: $error'),
      onStatus: (status) => print('STT Status: $status'),
    );
  }

  // Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  // Text-to-Speech Methods
  Future<void> speak() async {
    if (textToSpeak.isNotEmpty) {
      await flutterTts.speak(textToSpeak);
    }
  }

  Future<void> stop() async {
    await flutterTts.stop();
    isSpeaking = false;
  }

  Future<void> pause() async {
    await flutterTts.pause();

    isSpeaking = false;
  }

  // Speech-to-Text Methods
  Future<void> startListening(context) async {
    bool hasPermission = await requestMicrophonePermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Microphone permission denied')));
      return;
    }

    if (speechEnabled && !isListening) {
      recognizedWords = '';
      isListening = true;

      await speechToText.listen(
        onResult: (result) {
          recognizedWords = result.recognizedWords;
          if (result.finalResult) {
            isListening = false;
          }
        },
        localeId: selectedLocale,
      );
    }
  }

  Future<void> stopListening() async {
    if (isListening) {
      await speechToText.stop();
    }
  }
}
