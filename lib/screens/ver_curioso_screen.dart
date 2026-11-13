import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/curioso.dart';
import '../services/pocketbase_service.dart';
import '../services/local_storage_service.dart';

class VerCuriosoScreen extends StatefulWidget {
  final String curiosoId;
  final bool forzarReceptor;

  const VerCuriosoScreen({
    super.key,
    required this.curiosoId,
    this.forzarReceptor = false,
  });

  @override
  State<VerCuriosoScreen> createState() => _VerCuriosoScreenState();
}

class _VerCuriosoScreenState extends State<VerCuriosoScreen>
    with SingleTickerProviderStateMixin {
  Curioso? _curioso;
  TabController? _tabController;
  bool _cargando = true;
  bool _esDueno = false;
  bool _guardando = false;

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
    final controller = _tabController;
    _tabController = null;
    controller?.dispose();
    super.dispose();
  }

  Future<void> _cargarCurioso() async {
    final curioso = await PocketBaseService.obtenerCurioso(widget.curiosoId);
    if (!mounted) return;

    if (curioso == null) {
      setState(() {
        _curioso = null;
        _cargando = false;
      });
      return;
    }

    final uuid = await LocalStorageService.obtenerUuid();
    if (!mounted) return;

    final esDueno = widget.forzarReceptor ? false : curioso.creadorId == uuid;

    if (esDueno && !curioso.leidoPorDueno) {
      curioso.leidoPorDueno = true;
      await PocketBaseService.actualizarCurioso(curioso);
    }

    final totalTabs = curioso.participantes.length;

    if (_tabController == null || _tabController!.length != totalTabs) {
      final controllerAnterior = _tabController;
      _tabController = null;
      controllerAnterior?.dispose();

      _tabController = TabController(
        length: totalTabs,
        vsync: this,
        initialIndex: esDueno ? 0 : totalTabs - 1,
      );
    }

    setState(() {
      _curioso = curioso;
      _esDueno = esDueno;
      _cargando = false;
    });
  }

  String _tiempoRestante() {
    if (_curioso == null) return '';
    final diff = _curioso!.fechaExpiracion.difference(DateTime.now());
    if (diff.isNegative) return 'Expirado';
    final horas = diff.inHours;
    final minutos = diff.inMinutes % 60;
    if (horas > 0) return '${horas}h ${minutos}m restantes';
    return '${minutos}m restantes';
  }

  Future<void> _enviarANuevoReceptor() async {
    if (_curioso?.id == null) return;
    final link = 'https://contestar.alemaniac.online/curioso/${_curioso!.id}';
    final mensaje = '¡Contesta mi curioso! 🎯\n\nAbre este enlace:\n$link';
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
            content: Text('📋 Enlace copiado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _compartirCuriosoCompleto() async {
    if (_curioso == null) return;

    final receptores = _curioso!.receptores;
    if (receptores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay receptores para compartir')),
      );
      return;
    }

    final seleccionados = <String>{};

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.share, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('Compartir curioso'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona a quién enviar el curioso completo (solo lectura):',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 15),
              ...receptores.map((p) {
                final seleccionado = seleccionados.contains(p.dispositivoId);
                return CheckboxListTile(
                  title: Text(p.nombre),
                  subtitle: Text(p.email.isNotEmpty ? p.email : 'Sin email'),
                  value: seleccionado,
                  onChanged: (v) {
                    setDialogState(() {
                      if (v == true) {
                        seleccionados.add(p.dispositivoId);
                      } else {
                        seleccionados.remove(p.dispositivoId);
                      }
                    });
                  },
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: seleccionados.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Compartir'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      ),
    );

    if (confirmar == true && seleccionados.isNotEmpty) {
      setState(() => _guardando = true);
      _curioso!.compartidoCon =
          _curioso!.compartidoCon + seleccionados.toList();
      _curioso!.compartidoCon = _curioso!.compartidoCon.toSet().toList();
      await PocketBaseService.actualizarCurioso(_curioso!);
      if (mounted) setState(() => _guardando = false);

      final link =
          'https://contestar.alemaniac.online/curioso/${_curioso!.id}?lectura=1';
      final mensaje =
          '¡Mira el curioso completo! 📖\n\nAbre este enlace para leerlo:\n$link';
      try {
        await Share.share(
          mensaje,
          subject: '¡Mira el curioso completo!',
        );
      } catch (e) {
        await Clipboard.setData(ClipboardData(text: mensaje));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Curioso compartido'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esReceptor = !_esDueno;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8DC),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          esReceptor ? 'Personas que contestan' : 'Curioso',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _cargarCurioso,
            ),
        ],
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
                    p.nombre,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (p.esDueno)
                const Text('Dueño',
                    style: TextStyle(fontSize: 10, color: Colors.white70)),
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
      views.add(_buildTabParticipante(p, color));
    }
    return views;
  }

  Widget _buildTabParticipante(Participante participante, Color color) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCabecera(
            nombre: participante.nombre,
            esDueno: participante.esDueno,
            subtitulo:
                'Contestó: ${_formatearFecha(participante.fechaContestado)}',
            color: color,
          ),
          const SizedBox(height: 20),
          const Text('Sus respuestas a las 10 preguntas:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._curioso!.preguntas.asMap().entries.map((entry) {
            final respuesta =
                participante.respuestas10Fijas[entry.key.toString()];
            final textoRespuesta =
                (respuesta == null || respuesta.isEmpty) ? '—' : respuesta;
            return _buildPreguntaConRespuesta(
              numero: entry.key + 1,
              pregunta: entry.value,
              respuesta: textoRespuesta,
            );
          }),
          if (participante.preguntaExtra.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('❓ Su pregunta extra:',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple)),
            const SizedBox(height: 10),
            _buildPreguntaExtra(
              pregunta: participante.preguntaExtra,
              autor: participante.nombre,
              respuesta: participante.respuestaSuPregunta,
            ),
          ],
          if (participante.respuestasAExtras.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('❓ Sus respuestas a extras de otros:',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple)),
            const SizedBox(height: 10),
            ...participante.respuestasAExtras.entries.map((entry) {
              final autor = _buscarAutorPregunta(entry.key);
              return _buildPreguntaExtra(
                pregunta: entry.key,
                autor: autor,
                respuesta: entry.value,
              );
            }),
          ],
          if (participante.esDueno && _esDueno) ...[
            ..._buildExtrasPendientes(participante, color),
          ],
          if (_esDueno) ...[
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _curioso!.estaCompleto ||
                        _curioso!.receptores.length >= _curioso!.maxReceptores
                    ? _compartirCuriosoCompleto
                    : _enviarANuevoReceptor,
                icon: Icon(
                  _curioso!.estaCompleto ||
                          _curioso!.receptores.length >=
                              _curioso!.maxReceptores
                      ? Icons.share
                      : Icons.send,
                  color: Colors.white,
                ),
                label: Text(
                  _curioso!.estaCompleto ||
                          _curioso!.receptores.length >=
                              _curioso!.maxReceptores
                      ? 'Compartir curioso'
                      : 'Enviar a nuevo receptor',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _curioso!.estaCompleto ||
                              _curioso!.receptores.length >=
                                  _curioso!.maxReceptores
                          ? Colors.deepPurple
                          : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildExtrasPendientes(Participante p, Color color) {
    final pendientes = _curioso!.preguntasExtraPendientes(p);
    if (pendientes.isEmpty) return [];

    return [
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange, width: 2),
        ),
        child: const Row(
          children: [
            Icon(Icons.notification_important, color: Colors.orange, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tienes preguntas extra pendientes de contestar',
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
        final rondaOriginal = _buscarParticipantePorPregunta(pregunta);
        final respuestaOriginal = rondaOriginal?.respuestaSuPregunta ?? '';
        return _buildPreguntaExtraPendiente(
          pregunta: pregunta,
          autor: autor,
          respuestaOriginal: respuestaOriginal,
        );
      }),
    ];
  }

  Widget _buildPreguntaExtraPendiente({
    required String pregunta,
    required String autor,
    required String respuestaOriginal,
  }) {
    final controller = TextEditingController();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pregunta,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text('Pregunta de: $autor',
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: Colors.orange[300])),
          if (respuestaOriginal.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text('💬 $autor: "$respuestaOriginal"',
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Tu respuesta',
              hintText: 'Escribe aquí tu respuesta',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.edit_note, color: Colors.orange),
              filled: true,
              fillColor: Colors.white,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _guardando
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty) return;
                      await _guardarRespuestaDueno(pregunta, controller.text);
                      controller.clear();
                    },
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              label: const Text('Enviar respuesta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarRespuestaDueno(String pregunta, String respuesta) async {
    if (_curioso == null) return;
    setState(() => _guardando = true);

    final participantesActualizados =
        List<Participante>.from(_curioso!.participantes);
    final dueno = participantesActualizados.firstWhere((p) => p.esDueno);

    final nuevasRespuestas =
        Map<String, String>.from(dueno.respuestasAExtras);
    nuevasRespuestas[pregunta] = respuesta.trim();

    final duenoActualizado = Participante(
      nombre: dueno.nombre,
      email: dueno.email,
      dispositivoId: dueno.dispositivoId,
      esDueno: true,
      orden: dueno.orden,
      respuestas10Fijas: dueno.respuestas10Fijas,
      preguntaExtra: dueno.preguntaExtra,
      respuestaSuPregunta: dueno.respuestaSuPregunta,
      respuestasAExtras: nuevasRespuestas,
      fechaContestado: dueno.fechaContestado,
    );

    final index = participantesActualizados.indexOf(dueno);
    participantesActualizados[index] = duenoActualizado;
    _curioso!.participantes = participantesActualizados;

    final exito = await PocketBaseService.actualizarCurioso(_curioso!);

    if (!mounted) return;
    setState(() => _guardando = false);

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Respuesta guardada'),
          backgroundColor: Colors.green,
        ),
      );
      _cargarCurioso();
    }
  }

  String _buscarAutorPregunta(String pregunta) {
    if (_curioso == null) return 'Desconocido';
    for (final p in _curioso!.participantes) {
      if (p.preguntaExtra == pregunta) return p.nombre;
    }
    return 'Desconocido';
  }

  Participante? _buscarParticipantePorPregunta(String pregunta) {
    if (_curioso == null) return null;
    try {
      return _curioso!.participantes
          .firstWhere((p) => p.preguntaExtra == pregunta);
    } catch (_) {
      return null;
    }
  }

  Widget _buildCabecera({
    required String nombre,
    required bool esDueno,
    required String subtitulo,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                nombre,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              if (esDueno) ...[
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
          const SizedBox(height: 5),
          Text(subtitulo,
              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 5),
              Text(_tiempoRestante(),
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
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
                  fontWeight: FontWeight.bold, fontSize: 15)),
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
          Row(
            children: [
              const Icon(Icons.help_outline, color: Colors.purple, size: 18),
              const SizedBox(width: 5),
              Expanded(
                child: Text(pregunta,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.purple)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text('Pregunta de: $autor',
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: Colors.purple[300])),
          const SizedBox(height: 8),
          Text(respuesta,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
  }
}