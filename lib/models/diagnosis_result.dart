class DiagnosisResult {
  final String plantName;
  final String plantNameAr;
  final String diagnosis;
  final String diseaseType;
  final String treatment;
  final String details;
  final double confidence;
  final double plantNetConfidence;
  final String plantNetLabel;
  final double openAIPlantConfidence;
  final String openAIPlantLabel;
  final double modelDiseaseConfidence;
  final String modelDiseaseLabel;
  final double openAIDiseaseConfidence;
  final String openAIDiseaseLabel;
  final DiagnosisStatus status;
  final String imagePath;
  final DateTime timestamp;

  // Holds all the data from a completed plant diagnosis including plant name, disease info, confidence scores, and status
  DiagnosisResult({
    required this.plantName,
    required this.plantNameAr,
    required this.diagnosis,
    required this.diseaseType,
    required this.treatment,
    required this.details,
    required this.confidence,
    required this.status,
    required this.imagePath,
    required this.timestamp,
    this.plantNetConfidence      = 0.0,
    this.plantNetLabel           = '',
    this.openAIPlantConfidence   = 0.0,
    this.openAIPlantLabel        = '',
    this.modelDiseaseConfidence  = 0.0,
    this.modelDiseaseLabel       = '',
    this.openAIDiseaseConfidence = 0.0,
    this.openAIDiseaseLabel      = '',
  });
}

// Represents the possible outcomes of a diagnosis — healthy, diseased, failed, or still analyzing
enum DiagnosisStatus { healthy, diseased, failed, analyzing }

// Represents the three supported plant categories, each with an id, Arabic label, and emoji icon
enum PlantType {
  vegetablesFruits('vegetables-fruits', 'خضار وفواكه', '🥬'),
  mint('mint', 'النعناع', '🌿'),
  palm('palm', 'النخيل', '🌴');

  const PlantType(this.id, this.labelAr, this.icon);
  final String id;
  final String labelAr;
  final String icon;
}