/// Client-side `image-quality-v1` review validator (docs/tech-requirement-document.md).
/// Equality at the stated bounds passes; failed checks have NO override/bypass in MVP.

class ImageQualityMetrics {
  const ImageQualityMetrics({
    required this.laplacianVariance,
    required this.meanLuminance,
    required this.saturatedFraction,
    required this.subjectCheckPassed,
  });

  final double laplacianVariance;
  final double meanLuminance;
  final double saturatedFraction;
  final bool subjectCheckPassed;
}

class ImageQualityResult {
  const ImageQualityResult({required this.passed, required this.guidanceMessages});

  final bool passed;
  final List<String> guidanceMessages;
}

ImageQualityResult evaluateImageQualityV1(ImageQualityMetrics m) {
  final reasons = <String>[];
  if (m.laplacianVariance < 100.0) {
    reasons.add('Photo looks blurry — hold steady and focus on the affected leaf.');
  }
  if (m.meanLuminance < 40.0) {
    reasons.add('Too dark — move to brighter natural daylight.');
  }
  if (m.meanLuminance > 220.0) {
    reasons.add('Too bright — shade the leaf slightly from harsh midday sun.');
  }
  if (m.saturatedFraction > 0.15) {
    reasons.add('Too much glare — angle the camera to reduce reflections.');
  }
  if (!m.subjectCheckPassed) {
    reasons.add('No plant leaf or garden soil clearly detected in frame.');
  }
  return ImageQualityResult(passed: reasons.isEmpty, guidanceMessages: reasons);
}
