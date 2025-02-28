
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:matter/const.dart';
import 'package:matter/controllers/popup_styles.dart';
import 'package:matter/pages/home_page.dart';
import 'package:matter/prompts/prompts.dart';

class DebateController extends GetxController {
  final topicController = TextEditingController();

  final isDebating = false.obs;
  final isSpeaking = false.obs;
  final isAI1Speaking = true.obs;
  final ai1Response = ''.obs;
  final ai2Response = ''.obs;

  // Voice
  FlutterTts? flutterTts;
  final isTTSInitialized = false.obs;

  // AI Models
  late GenerativeModel model1;
  late GenerativeModel model2;
  late GenerativeModel model3;
  ChatSession? chatSession1;
  ChatSession? chatSession2;

  AnimationController? animationController;

  @override
  void onInit() {
    super.onInit();
    initializeTTS();
    initializeAI();
  }

  void showHarmfulContentDialog() {
    showCustomDialog(
      title: "'Harmful Content Detected'",
      middleText: "'Please enter a meaningful topic'",
    );
  }

  Future<void> initializeTTS() async {
    try {
      flutterTts = FlutterTts();
      await flutterTts!.getVoices;
      await flutterTts!.setLanguage("en-US");
      flutterTts!.setCompletionHandler(() {
        isSpeaking.value = false;
      });
      isTTSInitialized.value = true;
    } catch (e) {
      isTTSInitialized.value = false;
    }
  }

  void initializeAI() {
    model3 = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: GEMINI_API_KEY,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
      ],
    );
    // Initialize AI Model 1
    model1 = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: GEMINI_API_KEY,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
      ],
    );
    // Initialize AI Model 2
    model2 = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: GEMINI_API_KEY,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
      ],
    );
  }

  void showInvalidTopicDialog(String reason) {
    showCustomDialog(title: "Invalid Topic", middleText: reason);
  }

  Future<bool> validateTopic(String topic) async {
    try {
      final chat = model2.startChat();
      final validationResponse = await chat.sendMessage(Content.text(topicValidationPrompt(topic)));
      final validationRaw = validationResponse.text;
      final validation = validationRaw?.trim().toUpperCase() ?? '';
      if (validation == '**VALID**') {
        return true;
      } else if (validation == '**INVALID**') {
        showInvalidTopicDialog('The topic is unclear or not suitable for debate.');
        return false;
      } else {
        showInvalidTopicDialog('Unexpected response from AI. Please enter a well-formed, debatable topic.');
        return false;
      }
    } catch (e, stackTrace) {
      showInvalidTopicDialog('An error occurred while validating. Try again.');
      return false;
    }
  }

  void initializeDebate() {
    final topic = topicController.text;
    // Initialize Chat Session 1
    chatSession1 = model1.startChat(history: [
      Content.text(forSessionPrompt(topic))
    ]);
    // Initialize Chat Session 2
    chatSession2 = model2.startChat(history: [
      Content.text(skepticPrompt(topic))
    ]);
  }

  Future<void> speak(String text, bool isAI1) async {
    if (!isTTSInitialized.value || flutterTts == null) return;
    try {
      if (isSpeaking.value) {
        await flutterTts?.stop();
      }

      if (isAI1) {
        // Deep female voice with more natural parameters
        await flutterTts!.setVoice({
          "name": "en-US-Neural2-F", // Neural voice for more natural sound
          "locale": "en-US",
        });
        await flutterTts!.setPitch(0.85);  // Lower pitch for deeper female voice
        await flutterTts!.setVolume(1.0);
        await flutterTts!.setSpeechRate(0.5); // Slightly slower for more natural rhythm
      } else {
        // Deep male voice with more natural parameters
        await flutterTts!.setVoice({
          "name": "en-US-Neural2-D", // Neural voice for more natural sound
          "locale": "en-US",
        });
        await flutterTts!.setPitch(0.65);  // Good deep voice without sounding unnatural
        await flutterTts!.setVolume(1.0);
        await flutterTts!.setSpeechRate(0.5); // Slightly slower for clarity
      }

      // Add a slight pause between sentences to improve rhythm

      isSpeaking.value = true;
      await flutterTts?.speak(text);
    } catch (e) {
      isSpeaking.value = false;
      print("TTS Error: $e");
    }
  }


  Future<void> runDebate() async {
    if (!isDebating.value) return;
    try {
      GenerateContentResponse? response1;
      try {
        response1 = await chatSession1?.sendMessage(
          Content.text("Present your opening argument on the debate topic."),
        );
      } on GenerativeAIException catch (e) {
        stopDebate();
        showHarmfulContentDialog();
        return;
      }
      if (!isDebating.value) return;
      ai1Response.value = response1?.text ?? '';
      isAI1Speaking.value = true;
      await speak(ai1Response.value, true);
      while (isDebating.value) {
        await waitForSpeechCompletion();
        GenerateContentResponse? response2;
        try {
          isAI1Speaking.value = false;
          response2 = await chatSession2?.sendMessage(
            Content.text("Respond to this argument: ${ai1Response.value}"),
          );
        } on GenerativeAIException catch (e) {
          stopDebate();
          showHarmfulContentDialog();
          return;
        }
        if (!isDebating.value) break;
        ai2Response.value = response2?.text ?? '';
        await speak(ai2Response.value, false);
        await waitForSpeechCompletion();
        GenerateContentResponse? nextResponse1;
        try {
          isAI1Speaking.value = true;
          nextResponse1 = await chatSession1?.sendMessage(
            Content.text("Counter this point: ${ai2Response.value}"),
          );
        } on GenerativeAIException catch (e) {
          stopDebate();
          showHarmfulContentDialog();
          return;
        }
        if (!isDebating.value) break;
        ai1Response.value = nextResponse1?.text ?? '';
        await speak(ai1Response.value, true);
      }
    } catch (e) {
      stopDebate();
      showCustomDialog(
          title: "'Harmful Content Detected'",
          middleText: "'Please enter a meaningful topic'");
    }
  }

  Future<void> waitForSpeechCompletion() async {
    while (isSpeaking.value) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> startDebate() async {
    final topic = topicController.text.trim();
    final isValid = await validateTopic(topic);
    if (!isValid) {
      return;
    }
    isDebating.value = true;
    animationController?.repeat();
    initializeDebate();
    runDebate();
  }

  void stopDebate() {
    isDebating.value = false;
    animationController?.reset();
    isSpeaking.value = false;
    flutterTts?.stop();
    ai1Response.value = '';
    ai2Response.value = '';
  }

  void resetDebate() {
    stopDebate();
    topicController.clear();
    Get.back();
  }

  @override
  void onClose() {
    flutterTts?.stop();
    topicController.dispose();
    animationController?.dispose();
    super.onClose();
  }
}
