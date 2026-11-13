import 'package:flutter/material.dart';
import '../models/curioso.dart';
import '../services/pocketbase_service.dart';
import '../services/local_storage_service.dart';
import 'home_screen.dart';

class ContestarRondaScreen extends StatefulWidget {
  final String curiosoId;
  final bool forzarPestanaEscribir;

  const ContestarRondaScreen({
    super.key, 
    required this.curiosoId,
    this.forzarPestanaEscribir = false,
  });
  
  @override
  State<ContestarRondaScreen> createState() => _ContestarRondaScreenState();
}

class _ContestarRondaScreenState extends State<ContestarRondaScreen>
    with SingleTickerProviderStateMixin {
  Curioso? _curioso;
  TabController? _tabController;
  bool _cargando = true;
  bool _enviando = false;
  bool _modoReingreso = false;
  String _miUuid = '';

  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _preguntaExtraController = TextEditingController();
  final _respuestaMiPreguntaController = TextEditingController();
  final Map<String, TextEditingController> _respuestasControllers = {};
  final Map<String, TextEditingController> _respuestasExtrasControllers = {};

  final List<Color> _coloresParticipantes = [
    Colors.deepPurple,
    Colors.pink,
    Colors.green,
    Colors.orange,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _cargarCurioso();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _preguntaExtraController.dispose();
    _respuestaMiPreguntaController.dispose();
    for (final c in _respuestasControllers.values) {
      c.dispose();
    }
    for (final c in _respuestasExtrasControllers.values) {
      c.dispose();
    }
    final controller = _tabController;
    _tabController = null;
    controller?.dispose();
    super.dispose();
  }

  Future<void> _cargarCurioso() async {
    _miUuid = await LocalStorageService.obtenerUuid();
    final curioso = await PocketBaseService.obtenerCurioso(widget.curiosoId);
    if (!mounted) return;

    if (curioso == null) {
      setState(() {
        _curioso = null;
        _cargando = false;
      });
      return;
    }

    final miParticipante = curioso.participantePorDispositivo(_miUuid);
    final modoReingreso = miParticipante != null;

    if (modoReingreso) {
      _nombreController.text = miParticipante.nombre;
      _emailController.text = miParticipante.email;
      _preguntaExtraController.text = miParticipante.preguntaExtra;
      _respuestaMiPreguntaController.text = miParticipante.respuestaSuPregunta;

      final pendientes = curioso.preguntasExtraPendientes(miParticipante);
      for (final pregunta in pendientes) {
        _respuestasExtrasControllers[pregunta] = TextEditingController();
      }
    } else {
      for (final pregunta in curioso.preguntas) {
        _respuestasControllers[pregunta] = TextEditingController();
      }
      for (final p in curioso.participantes) {
        if (p.preguntaExtra.isNotEmpty) {
          _respuestasExtrasControllers[p.preguntaExtra] =
              TextEditingController();
        }
      }
    }

    final totalTabs = modoReingreso
        ? curioso.participantes.length
        : curioso.participantes.length + 1;

    final controllerAnterior = _tabController;
    _tabController = null;
    controllerAnterior?.dispose();

    _tabController = TabController(
      length: totalTabs,
      vsync: this,
      initialIndex: widget.forzarPestanaEscribir ? totalTabs - 1 : (modoReingreso ? 0 : totalTabs - 1),
    );

    setState(() {
      _curioso = curioso;
      _cargando = false;
      _modoReingreso = modoReingreso;
    });
  }

  Future<void> _enviar() async {
    if (_curioso == null) return;

    if (!_modoReingreso) {
      if (_nombreController.text.trim().isEmpty) {
        _mensaje('Ingresa tu nombre');
        return;
      }

      for (final entry in _respuestasControllers.entries) {
        if (entry.value.text.trim().isEmpty) {
          _mensaje('Contesta todas las preguntas');
          return;
        }
      }

      for (final entry in _respuestasExtrasControllers.entries) {
        if (entry.value.text.trim().isEmpty) {
          _mensaje('Contesta las preguntas extra de otros');
          return;
        }
      }

      final preguntaExtra = _preguntaExtraController.text.trim();
      final respuestaMiPregunta = _respuestaMiPreguntaController.text.trim();

      if (preguntaExtra.isNotEmpty && respuestaMiPregunta.isEmpty) {
        _mensaje('Responde tu propia pregunta extra');
        return;
      }
    } else {
      for (final entry in _respuestasExtrasControllers.entries) {
        if (entry.value.text.trim().isEmpty) {
          _mensaje('Contesta las preguntas extra pendientes');
          return;
        }
      }
    }

    setState(() => _enviando = true);

    if (_modoReingreso) {
      final participantesActualizados =
          List<Participante>.from(_curioso!.participantes);
      final index = participantesActualizados.indexWhere(
          (p) => p.dispositivoId == _miUuid);

      if (index == -1) {
        setState(() => _enviando = false);
        _mensaje('Error: no se encontró tu hoja');
        return;
      }

      final actual = participantesActualizados[index];
      final nuevasRespuestas =
          Map<String, String>.from(actual.respuestasAExtras);

      for (final entry in _respuestasExtrasControllers.entries) {
        nuevasRespuestas[entry.key] = entry.value.text.trim();
      }

      participantesActualizados[index] = Participante(
        nombre: actual.nombre,
        email: actual.email,
        dispositivoId: actual.dispositivoId,
        esDueno: actual.esDueno,
        orden: actual.orden,
        respuestas10Fijas: actual.respuestas10Fijas,
        preguntaExtra: actual.preguntaExtra,
        respuestaSuPregunta: actual.respuestaSuPregunta,
        respuestasAExtras: nuevasRespuestas,
        fechaContestado: DateTime.now(),
      );

      _curioso!.participantes = participantesActualizados;
    } else {
      final respuestas10Fijas = <String, String>{};
      int indice = 0;
      for (final entry in _respuestasControllers.entries) {
        respuestas10Fijas[indice.toString()] = entry.value.text.trim();
        indice++;
      }

      final respuestasAExtras = <String, String>{};
      for (final entry in _respuestasExtrasControllers.entries) {
        respuestasAExtras[entry.key] = entry.value.text.trim();
      }

      final nuevoParticipante = Participante(
        nombre: _nombreController.text.trim(),
        email: _emailController.text.trim(),
        dispositivoId: _miUuid,
        esDueno: false,
        orden: _curioso!.participantes.length + 1,
        respuestas10Fijas: respuestas10Fijas,
        preguntaExtra: _preguntaExtraController.text.trim(),
        respuestaSuPregunta: _respuestaMiPreguntaController.text.trim(),
        respuestasAExtras: respuestasAExtras,
        fechaContestado: DateTime.now(),
      );

      final participantesActualizados =
          List<Participante>.from(_curioso!.participantes);
      participantesActualizados.add(nuevoParticipante);
      _curioso!.participantes = participantesActualizados;
    }

    if (_curioso!.receptores.length >= _curioso!.maxReceptores) {
      _curioso!.estadoGeneral = 'completado';
    }

    final exito = await PocketBaseService.actualizarCurioso(_curioso!);

    if (!mounted) return;

    if (exito) {
      await LocalStorageService.marcarComoContestado(widget.curiosoId);
      if (mounted) {
        _mensaje('¡Respuestas enviadas!');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      setState(() => _enviando = false);
      _mensaje('Error al enviar');
    }
  }

  void _mensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        title: Text(
          _modoReingreso ? 'Completar Extras' : 'Contestar Curioso',
          style: const TextStyle(color: Colors.white),
        ),
        bottom: _tabController != null && _curioso != null
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: _buildTabs(),
              )
            : null,
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
              : _curioso == null
                  ? _buildNoEncontrado()
                  : _tabController == null
                      ? const Center(child: CircularProgressIndicator())
                      : SafeArea( 
                          child: TabBarView(
                            controller: _tabController,
                            children: _buildTabViews(),
                          ),
                        ),
        ],
      ),
    );
  }

  Widget _buildNoEncontrado() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 80, color: Colors.red),
          SizedBox(height: 20),
          Text('Curioso no encontrado',
              style: TextStyle(fontSize: 20, color: Colors.grey)),
        ],
      ),
    );
  }

  List<Widget> _buildTabs() {
    if (_curioso == null) return [];

    final tabs = <Widget>[];
    for (int i = 0; i < _curioso!.participantes.length; i++) {
      final p = _curioso!.participantes[i];
      final color = _coloresParticipantes[i % _coloresParticipantes.length];
      final esMia = p.dispositivoId == _miUuid;

      tabs.add(
        Tab(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    esMia ? '${p.nombre} (Tú)' : p.nombre,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (p.esDueno)
                const Text('Dueño',
                    style: TextStyle(fontSize: 10, color: Colors.white70))
              else if (esMia)
                const Text('Tu hoja',
                    style: TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (!_modoReingreso) {
      tabs.add(
        const Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_note, size: 18),
              SizedBox(width: 4),
              Text('Tu hoja', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return tabs;
  }

  List<Widget> _buildTabViews() {
    if (_curioso == null) return [];

    final views = <Widget>[];
    for (int i = 0; i < _curioso!.participantes.length; i++) {
      final p = _curioso!.participantes[i];
      final color = _coloresParticipantes[i % _coloresParticipantes.length];
      final esMia = p.dispositivoId == _miUuid;

      if (esMia && _modoReingreso) {
        views.add(_buildMiHojaReingreso(p, color));
      } else {
        views.add(_buildTabParticipanteLectura(p, color));
      }
    }

    if (!_modoReingreso) {
      views.add(_buildFormularioCompleto());
    }

    return views;
  }

  Widget _buildMiHojaReingreso(Participante p, Color color) {
    final pendientes = _curioso!.preguntasExtraPendientes(p);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text(
                  p.nombre,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Tú',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Tus respuestas anteriores:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._curioso!.preguntas.asMap().entries.map((entry) {
            final respuesta = p.respuestas10Fijas[entry.key.toString()];
            final textoRespuesta =
                (respuesta == null || respuesta.isEmpty) ? '—' : respuesta;
            return _buildPreguntaConRespuesta(
              numero: entry.key + 1,
              pregunta: entry.value,
              respuesta: textoRespuesta,
            );
          }),
          if (p.preguntaExtra.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Tu pregunta extra:',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple)),
            const SizedBox(height: 10),
            _buildPreguntaExtra(
              pregunta: p.preguntaExtra,
              autor: p.nombre,
              respuesta: p.respuestaSuPregunta,
            ),
          ],
          if (p.respuestasAExtras.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Tus respuestas a extras anteriores:',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple)),
            const SizedBox(height: 10),
            ...p.respuestasAExtras.entries.map((entry) {
              final autor = _buscarAutorPregunta(entry.key);
              return _buildPreguntaExtra(
                pregunta: entry.key,
                autor: autor,
                respuesta: entry.value,
              );
            }),
          ],
          if (pendientes.isNotEmpty) ...[
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: const Row(
                children: [
                  Icon(Icons.notification_important,
                      color: Colors.orange, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Preguntas extra pendientes de contestar',
                      style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            ...pendientes.map((pregunta) {
              final autor = _buscarAutorPregunta(pregunta);
              final respuestaOriginal = _buscarRespuestaOriginal(pregunta);
              final controller = _respuestasExtrasControllers[pregunta];
              if (controller == null) return const SizedBox();

              return _buildPreguntaExtraField(
                pregunta: pregunta,
                autor: autor,
                respuestaOriginal: respuestaOriginal,
                controller: controller,
              );
            }),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _enviar,
                icon: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                label: Text(
                  _enviando ? 'Enviando...' : 'Enviar Respuestas',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¡No tienes preguntas pendientes!',
                      style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormularioCompleto() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Llena tu hoja del cuaderno. Opcionalmente puedes agregar tu propia pregunta.',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Tu nombre:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _nombreController,
            decoration: InputDecoration(
              labelText: 'Tu nombre',
              hintText: 'Ej: María',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.email),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 25),
          const Text('Responde las 10 preguntas:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._curioso!.preguntas.asMap().entries.map((entry) {
            final controller = _respuestasControllers[entry.value]!;
            return _buildPreguntaField(
              numero: entry.key + 1,
              pregunta: entry.value,
              controller: controller,
            );
          }),
          if (_respuestasExtrasControllers.isNotEmpty) ...[
            const SizedBox(height: 25),
            const Text('❓ Preguntas extra de otros:',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple)),
            const SizedBox(height: 10),
            ..._respuestasExtrasControllers.entries.map((entry) {
              final autor = _buscarAutorPregunta(entry.key);
              final respuestaOriginal = _buscarRespuestaOriginal(entry.key);
              return _buildPreguntaExtraField(
                pregunta: entry.key,
                autor: autor,
                respuestaOriginal: respuestaOriginal,
                controller: entry.value,
              );
            }),
          ],
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.help_outline, color: Colors.purple, size: 18),
                    SizedBox(width: 5),
                    Text('Tu pregunta extra (opcional):',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple)),
                  ],
                ),
                const SizedBox(height: 5),
                const Text('(Será contestada por los demás)',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 10),
                TextField(
                  controller: _preguntaExtraController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  minLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Escribe tu pregunta',
                    hintText: 'Ej: ¿Cuál es tu mayor secreto?',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.help_outline),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),
                const Text('Tu respuesta a tu propia pregunta:',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple)),
                const SizedBox(height: 5),
                const Text('(Obligatorio si escribiste una pregunta)',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 10),
                TextField(
                  controller: _respuestaMiPreguntaController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  minLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Tu respuesta',
                    hintText: 'Ej: Mi mayor secreto es...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.edit_note),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _enviando ? null : _enviar,
              icon: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              label: Text(
                _enviando ? 'Enviando...' : 'Enviar Respuestas',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabParticipanteLectura(Participante p, Color color) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text(
                  p.nombre,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                if (p.esDueno) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Dueño',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Sus respuestas:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._curioso!.preguntas.asMap().entries.map((entry) {
            final respuesta = p.respuestas10Fijas[entry.key.toString()];
            final textoRespuesta =
                (respuesta == null || respuesta.isEmpty) ? '—' : respuesta;
            return _buildPreguntaConRespuesta(
              numero: entry.key + 1,
              pregunta: entry.value,
              respuesta: textoRespuesta,
            );
          }),
          if (p.preguntaExtra.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('❓ Su pregunta extra:',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple)),
            const SizedBox(height: 10),
            _buildPreguntaExtra(
              pregunta: p.preguntaExtra,
              autor: p.nombre,
              respuesta: p.respuestaSuPregunta,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreguntaConRespuesta({
    required int numero,
    required String pregunta,
    required String respuesta,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$numero. $pregunta',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text(respuesta,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildPreguntaExtra({
    required String pregunta,
    required String autor,
    required String respuesta,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pregunta,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.purple)),
          const SizedBox(height: 3),
          Text('Pregunta de: $autor',
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                  color: Colors.purple[300])),
          const SizedBox(height: 8),
          Text(respuesta,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildPreguntaField({
    required int numero,
    required String pregunta,
    required TextEditingController controller,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$numero. $pregunta',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Tu respuesta',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
              prefixIcon: const Icon(Icons.edit_note,
                  size: 20, color: Colors.green),
              filled: true,
              fillColor: Colors.white,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildPreguntaExtraField({
    required String pregunta,
    required String autor,
    required String respuestaOriginal,
    required TextEditingController controller,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pregunta,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.purple)),
          const SizedBox(height: 3),
          Text('Pregunta de: $autor',
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                  color: Colors.purple[300])),
          if (respuestaOriginal.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text('💬 $autor: "$respuestaOriginal"',
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Tu respuesta',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
              prefixIcon: const Icon(Icons.edit_note,
                  size: 20, color: Colors.purple),
              filled: true,
              fillColor: Colors.white,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  String _buscarAutorPregunta(String pregunta) {
    if (_curioso == null) return 'Desconocido';
    for (final p in _curioso!.participantes) {
      if (p.preguntaExtra == pregunta) return p.nombre;
    }
    return 'Desconocido';
  }

  String _buscarRespuestaOriginal(String pregunta) {
    if (_curioso == null) return '';
    for (final p in _curioso!.participantes) {
      if (p.preguntaExtra == pregunta) return p.respuestaSuPregunta;
    }
    return '';
  }
}