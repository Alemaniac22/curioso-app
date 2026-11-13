import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/curioso.dart';
import '../services/pocketbase_service.dart';
import '../services/local_storage_service.dart';
import 'mis_curiosos_screen.dart';
import 'home_screen.dart';

const int maxReceptoresFree = 6;
const int maxEdiciones = 3;

class CrearCuriosoScreen extends StatefulWidget {
  const CrearCuriosoScreen({super.key});

  @override
  State<CrearCuriosoScreen> createState() => _CrearCuriosoScreenState();
}

class _CrearCuriosoScreenState extends State<CrearCuriosoScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _maxReceptoresController =
      TextEditingController(text: '3');
  final List<TextEditingController> _preguntasControllers =
      List.generate(10, (_) => TextEditingController());
  final List<TextEditingController> _respuestasControllers =
      List.generate(10, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(10, (_) => FocusNode());

  int _edicionesDisponibles = maxEdiciones;
  bool _cargando = false;

  final List<String> _preguntasSugeridas = [
    '¿Dónde vives?',
    '¿Cuál es tu teléfono?',
    '¿Tienes mascota?',
    '¿Cuál es tu comida favorita?',
    '¿Qué música te gusta?',
    '¿Cuál es tu color favorito?',
    '¿Qué haces en tu tiempo libre?',
    '¿Cuál es tu película favorita?',
    '¿A dónde te gustaría viajar?',
    '¿Cuál es tu mayor sueño?',
  ];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 10; i++) {
      _preguntasControllers[i].text = _preguntasSugeridas[i];
      _focusNodes[i].addListener(() {
        if (!_focusNodes[i].hasFocus) {
          _contarEdicion(i);
        }
      });
    }
  }

  void _contarEdicion(int index) {
    if (_edicionesDisponibles <= 0) return;
    final textoActual = _preguntasControllers[index].text.trim();
    final textoSugerido = _preguntasSugeridas[index];
    if (textoActual != textoSugerido) {
      setState(() {
        _edicionesDisponibles--;
      });
      if (_edicionesDisponibles == 0) {
        _mostrarMensajePremium('Has agotado tus ediciones gratis. Obtén Curioso Premium para editar sin límites.');
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _maxReceptoresController.dispose();
    for (var controller in _preguntasControllers) {
      controller.dispose();
    }
    for (var controller in _respuestasControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _crearYCompartir() async {
    if (_nombreController.text.isEmpty) {
      _mostrarMensaje('Completa tu nombre');
      return;
    }

    for (int i = 0; i < 10; i++) {
      if (_respuestasControllers[i].text.trim().isEmpty) {
        _mostrarMensaje('Contesta todas las preguntas (${i + 1})');
        return;
      }
    }

    final maxReceptores = int.tryParse(_maxReceptoresController.text.trim());
    if (maxReceptores == null || maxReceptores < 1) {
      _mostrarMensaje('Ingresa un número válido de personas');
      return;
    }

    if (maxReceptores > maxReceptoresFree) {
      if (mounted) {
        _mostrarMensajePremium('La versión gratis permite máximo $maxReceptoresFree personas. Obtén Curioso Premium para compartir con más.');
      }
      return;
    }

    final puede = await LocalStorageService.puedeCrearCurioso();
    if (!puede) {
      if (mounted) {
        _mostrarMensajePremium('Has alcanzado el límite de 3 curiosos gratis. Obtén Curioso Premium para crear ilimitados.');
      }
      return;
    }

    final preguntas = _preguntasControllers
        .map((c) => c.text.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (preguntas.length < 10) {
      _mostrarMensaje('Completa las 10 preguntas');
      return;
    }

    setState(() => _cargando = true);

    final uuid = await LocalStorageService.obtenerUuid();
    await LocalStorageService.guardarNombre(_nombreController.text);
    if (_emailController.text.isNotEmpty) {
      await LocalStorageService.guardarEmail(_emailController.text);
    }

    final respuestas10Fijas = <String, String>{};
    for (int i = 0; i < 10; i++) {
      respuestas10Fijas[i.toString()] = _respuestasControllers[i].text.trim();
    }

    final participanteDueno = Participante(
      nombre: _nombreController.text,
      email: _emailController.text,
      dispositivoId: uuid,
      esDueno: true,
      orden: 1,
      respuestas10Fijas: respuestas10Fijas,
      preguntaExtra: '',
      respuestaSuPregunta: '',
      respuestasAExtras: {},
      fechaContestado: DateTime.now(),
    );

    final curioso = Curioso(
      nombre: _nombreController.text,
      creadorId: uuid,
      creadorEmail: _emailController.text,
      preguntas: preguntas,
      participantes: [participanteDueno],
      maxReceptores: maxReceptores,
      estadoGeneral: 'en_progreso',
    );

    final resultado = await PocketBaseService.crearCurioso(curioso);

    setState(() => _cargando = false);

    if (resultado != null && resultado.id != null) {
      await LocalStorageService.agregarCuriosoLocal(resultado.id!);
      await LocalStorageService.incrementarContador();
      if (mounted) _mostrarDialogoCompartir(resultado);
    } else {
      if (mounted) _mostrarMensaje('Error al crear el curioso');
    }
  }

  void _mostrarMensajePremium(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✨ Obtén Curioso Premium', style: TextStyle(color: Colors.deepPurple)),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ahora no', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('La compra estará disponible próximamente.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Ver Premium'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCompartir(Curioso curioso) {
    final link = 'https://contestar.alemaniac.online/curioso/${curioso.id}';
    final mensaje = '¡Contesta mi curioso! 🎯\n\nAbre este enlace:\n$link';

    void irAMisCuriosos() {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MisCuriososScreen()),
        (Route<dynamic> route) => false,
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¡Curioso creado!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personas que contestarán: ${curioso.maxReceptores}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Comparte este enlace:'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(color: Colors.blue, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              irAMisCuriosos();
            },
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await Share.share(
                  mensaje,
                  subject: '¡Contesta mi curioso!',
                );
              } catch (e) {
                await Clipboard.setData(ClipboardData(text: mensaje));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 Enlace copiado. Pégalo donde quieras.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
              if (mounted) {
                Navigator.pop(dialogContext);
                irAMisCuriosos();
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Compartir'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloqueado = _edicionesDisponibles <= 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.home, color: Colors.white),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
        title: const Text('Crear Curioso',
            style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/fondo_curioso.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.75)),
          ),
          _cargando
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Información básica',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _nombreController,
                        decoration: InputDecoration(
                          labelText: 'Tu nombre',
                          hintText: 'Ej: Alejandro',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.person),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Tu email (opcional)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.email),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _maxReceptoresController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Personas que contestarán',
                          hintText: '1 a $maxReceptoresFree',
                          helperText:
                              'Sin contar al dueño. Free: hasta $maxReceptoresFree.',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.people),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 25),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bloqueado
                              ? Colors.green.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: bloqueado
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              bloqueado ? Icons.check_circle : Icons.edit,
                              color: bloqueado
                                  ? Colors.green.shade700
                                  : Colors.blue.shade700,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                bloqueado
                                    ? '✅ Ediciones completadas. Ahora contesta.'
                                    : 'Las preguntas son modificables: $_edicionesDisponibles/$maxEdiciones',
                                style: TextStyle(
                                  color: bloqueado
                                      ? Colors.green.shade900
                                      : Colors.blue.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange.shade700, width: 2),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange.shade800, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Después contesta cada pregunta',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Edita las preguntas (máx $maxEdiciones):',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      ...List.generate(10, (i) {
                        return _buildPreguntaYRespuesta(i, bloqueado);
                      }),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _crearYCompartir,
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: const Text('Crear y Compartir',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPreguntaYRespuesta(int index, bool bloqueado) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    bloqueado ? Colors.grey : Colors.deepPurple,
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _preguntasControllers[index],
                  focusNode: _focusNodes[index],
                  readOnly: bloqueado,
                  enabled: !bloqueado,
                  decoration: InputDecoration(
                    hintText: 'Escribe la pregunta',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    isDense: true,
                    suffixIcon: bloqueado
                        ? const Icon(Icons.lock,
                            size: 16, color: Colors.grey)
                        : null,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _respuestasControllers[index],
            decoration: InputDecoration(
              labelText: 'Tu respuesta',
              hintText: 'Escribe tu respuesta',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              isDense: true,
              prefixIcon: const Icon(Icons.edit_note,
                  size: 20, color: Colors.green),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}