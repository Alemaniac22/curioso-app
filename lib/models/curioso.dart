class Curioso {
  String? id;
  String nombre;
  String creadorId;
  String creadorEmail;
  List<String> preguntas;
  List<Participante> participantes;
  int maxReceptores;
  String estadoGeneral;
  DateTime fechaCreacion;
  DateTime fechaExpiracion;
  bool leidoPorDueno;
  List<String> compartidoCon;

  Curioso({
    this.id,
    required this.nombre,
    required this.creadorId,
    required this.creadorEmail,
    required this.preguntas,
    required this.participantes,
    required this.maxReceptores,
    this.estadoGeneral = 'en_progreso',
    DateTime? fechaCreacion,
    DateTime? fechaExpiracion,
    this.leidoPorDueno = false,
    List<String>? compartidoCon,
  })  : fechaCreacion = fechaCreacion ?? DateTime.now(),
        fechaExpiracion = fechaExpiracion ?? DateTime.now().add(const Duration(days: 1)),
        compartidoCon = compartidoCon ?? [];

  // Getters útiles
  bool get estaCompleto => estadoGeneral == 'completado';
  bool get estaExpirado => DateTime.now().isAfter(fechaExpiracion);

  List<Participante> get receptores =>
      participantes.where((p) => !p.esDueno).toList();

  Participante? participantePorDispositivo(String dispositivoId) {
    try {
      return participantes.firstWhere((p) => p.dispositivoId == dispositivoId);
    } catch (_) {
      return null;
    }
  }

  List<String> preguntasExtraPendientes(Participante participante) {
    final pendientes = <String>[];
    for (final p in participantes) {
      if (p.preguntaExtra.isNotEmpty && 
          p.dispositivoId != participante.dispositivoId && 
          !participante.respuestasAExtras.containsKey(p.preguntaExtra)) {
        pendientes.add(p.preguntaExtra);
      }
    }
    return pendientes;
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'creadorId': creadorId,
      'creadorEmail': creadorEmail,
      'preguntas': preguntas,
      'participantes': participantes.map((p) => p.toJson()).toList(),
      'maxReceptores': maxReceptores,
      'estadoGeneral': estadoGeneral,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fechaExpiracion': fechaExpiracion.toIso8601String(),
      'leidoPorDueno': leidoPorDueno,
      'compartidoCon': compartidoCon,
    };
  }

  factory Curioso.fromJson(Map<String, dynamic> json, String id) {
    return Curioso(
      id: id,
      nombre: json['nombre'] ?? '',
      creadorId: json['creadorId'] ?? '',
      creadorEmail: json['creadorEmail'] ?? '',
      preguntas: List<String>.from(json['preguntas'] ?? []),
      participantes: (json['participantes'] as List? ?? [])
          .map((p) => Participante.fromJson(p))
          .toList(),
      maxReceptores: json['maxReceptores'] ?? 3,
      estadoGeneral: json['estadoGeneral'] ?? 'en_progreso',
      fechaCreacion: json['fechaCreacion'] != null 
          ? DateTime.parse(json['fechaCreacion']) 
          : DateTime.now(),
      fechaExpiracion: json['fechaExpiracion'] != null 
          ? DateTime.parse(json['fechaExpiracion']) 
          : DateTime.now().add(const Duration(days: 1)),
      leidoPorDueno: json['leidoPorDueno'] ?? false,
      compartidoCon: List<String>.from(json['compartidoCon'] ?? []),
    );
  }
}

class Participante {
  String nombre;
  String email;
  String dispositivoId;
  bool esDueno;
  int orden;
  Map<String, String> respuestas10Fijas;
  String preguntaExtra;
  String respuestaSuPregunta;
  Map<String, String> respuestasAExtras;
  DateTime fechaContestado;

  Participante({
    required this.nombre,
    required this.email,
    required this.dispositivoId,
    required this.esDueno,
    required this.orden,
    required this.respuestas10Fijas,
    required this.preguntaExtra,
    required this.respuestaSuPregunta,
    required this.respuestasAExtras,
    required this.fechaContestado,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'email': email,
      'dispositivoId': dispositivoId,
      'esDueno': esDueno,
      'orden': orden,
      'respuestas10Fijas': respuestas10Fijas,
      'preguntaExtra': preguntaExtra,
      'respuestaSuPregunta': respuestaSuPregunta,
      'respuestasAExtras': respuestasAExtras,
      'fechaContestado': fechaContestado.toIso8601String(),
    };
  }

  factory Participante.fromJson(Map<String, dynamic> json) {
    return Participante(
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
      dispositivoId: json['dispositivoId'] ?? '',
      esDueno: json['esDueno'] ?? false,
      orden: json['orden'] ?? 1,
      respuestas10Fijas: Map<String, String>.from(json['respuestas10Fijas'] ?? {}),
      preguntaExtra: json['preguntaExtra'] ?? '',
      respuestaSuPregunta: json['respuestaSuPregunta'] ?? '',
      respuestasAExtras: Map<String, String>.from(json['respuestasAExtras'] ?? {}),
      fechaContestado: json['fechaContestado'] != null 
          ? DateTime.parse(json['fechaContestado']) 
          : DateTime.now(),
    );
  }
}