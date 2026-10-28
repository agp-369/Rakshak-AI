import 'package:flutter_gemma/flutter_gemma.dart';

enum ModelTier { tiny, small, full }

extension ModelTierExt on ModelTier {
  String get id {
    switch (this) {
      case ModelTier.tiny:
        return 'tiny';
      case ModelTier.small:
        return 'small';
      case ModelTier.full:
        return 'full';
    }
  }

  String get displayNameHi {
    switch (this) {
      case ModelTier.tiny:
        return 'छोटा - Tiny (270M)';
      case ModelTier.small:
        return 'मध्यम - Small (1B)';
      case ModelTier.full:
        return 'पूर्ण - Full (E2B)';
    }
  }

  String get displayNameEn {
    switch (this) {
      case ModelTier.tiny:
        return 'Tiny (270M)';
      case ModelTier.small:
        return 'Small (1B)';
      case ModelTier.full:
        return 'Full (E2B)';
    }
  }

  String get descriptionEn {
    switch (this) {
      case ModelTier.tiny:
        return 'Fast entity extraction & panic voice triage. Ultra-low memory for 2-3 GB RAM budget phones.';
      case ModelTier.small:
        return 'Extraction, full survival protocol Q&A & alert interpretation. Best balance for 3-4 GB RAM phones.';
      case ModelTier.full:
        return 'Multimodal reasoning & detailed situational briefing. Recommended for 6 GB+ RAM or control hubs.';
    }
  }

  String get descriptionHi {
    switch (this) {
      case ModelTier.tiny:
        return 'आवाज़ विश्लेषण और तेज़ आपातकालीन ट्रायज। 2-3 GB RAM वाले बजट फ़ोनों के लिए उपयुक्त।';
      case ModelTier.small:
        return 'बचाव निर्देश, चेतावनी अनुवाद और सवाल-जवाब। 3-4 GB RAM वाले फ़ोनों के लिए सर्वोत्तम।';
      case ModelTier.full:
        return 'विस्तृत रिपोर्टिंग और बहुआयामी समझ। 6 GB+ RAM या राहत नियंत्रण कक्ष के लिए।';
    }
  }

  String get modelFile {
    switch (this) {
      case ModelTier.tiny:
        return 'gemma-3-270m-it-q8.litertlm';
      case ModelTier.small:
        return 'gemma-3-1b-it-int4.litertlm';
      case ModelTier.full:
        return 'gemma-4-E2B-it.litertlm';
    }
  }

  ModelType get gemmaModelType {
    switch (this) {
      case ModelTier.tiny:
        return ModelType.gemmaIt;
      case ModelTier.small:
        return ModelType.gemmaIt;
      case ModelTier.full:
        return ModelType.gemma4;
    }
  }

  int get sizeMb {
    switch (this) {
      case ModelTier.tiny:
        return 304;
      case ModelTier.small:
        return 584;
      case ModelTier.full:
        return 2560;
    }
  }

  int get minRamMb {
    switch (this) {
      case ModelTier.tiny:
        return 1024;
      case ModelTier.small:
        return 2048;
      case ModelTier.full:
        return 6144;
    }
  }

  bool get recommendedForLowRam {
    switch (this) {
      case ModelTier.tiny:
        return true;
      case ModelTier.small:
        return true;
      case ModelTier.full:
        return false;
    }
  }

  String get defaultDownloadUrl {
    switch (this) {
      case ModelTier.tiny:
        return 'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma-3-270m-it-q8.litertlm';
      case ModelTier.small:
        return 'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma-3-1b-it-int4.litertlm';
      case ModelTier.full:
        return 'https://huggingface.co/google/gemma-4-E2B-it/resolve/main/gemma-4-E2B-it.litertlm';
    }
  }
}

class ModelPackInfo {
  final ModelTier tier;
  final String downloadUrl;
  final String sha256;
  final String license;
  final String notes;

  const ModelPackInfo({
    required this.tier,
    required this.downloadUrl,
    required this.sha256,
    required this.license,
    required this.notes,
  });
}
