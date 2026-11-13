import 'package:flutter/material.dart';
import '../models/curioso.dart';
import '../services/pocketbase_service.dart';
import '../services/local_storage_service.dart';
import 'ver_curioso_screen.dart';
import 'home_screen.dart';

class MisCuriososScreen extends StatefulWidget {
  const MisCuriososScreen({super.key});

  @override
  State<MisCuriososScreen> createState() => _MisCuriososScreenState();
}

class _MisCuriososScreenState extends State<MisCuriososScreen> {
  List<Curioso> _curiosos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCuriosos();
  }

  Future<void> _cargarCuriosos() async {
    setState(() => _cargando = true);
    final uuid = await LocalStorageService.obtenerUuid();
    final curiosos = await PocketBaseService.listarCuriososPorId(uuid);
    curiosos.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    setState(() {
      _curiosos = curiosos;
      _cargando = false;
    });
  }

  String _tiempoRestante(Curioso curioso) {
    final diff = curioso.fechaExpiracion.difference(DateTime.now());
    if (diff.isNegative) return 'Expirado';
    final horas = diff.inHours;
    final minutos = diff.inMinutes % 60;
    if (horas > 0) return '${horas}h ${minutos}m';
    return '${minutos}m';
  }

  Color _colorEstado(Curioso curioso) {
    if (curioso.estaCompleto) return Colors.red;
    if (curioso.receptores.isNotEmpty) return Colors.green;
    return Colors.blue;
  }

  String _textoEstado(Curioso curioso) {
    if (curioso.estaCompleto) return 'Completo';
    if (curioso.receptores.isNotEmpty) {
      return '${curioso.receptores.length} participantes';
    }
    return 'Pendiente';
  }

  Future<void> _eliminarCurioso(Curioso curioso) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar curioso?'),
        content: const Text(
          'Esta acción no se puede deshacer.\n\n'
          '⚠️ Perderás el cupo de este curioso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true && curioso.id != null) {
      final exito = await PocketBaseService.eliminarCurioso(curioso.id!);
      if (exito) {
        await LocalStorageService.eliminarCuriosoLocal(curioso.id!);
        _cargarCuriosos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Curioso eliminado')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Mis Curiosos',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.star, color: Colors.amber),
            tooltip: 'Curioso Premium',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('✨ Curioso Premium', style: TextStyle(color: Colors.deepPurple)),
                  content: const Text('Disfruta de curiosos ilimitados y beneficios exclusivos por solo \$1,99 cada 6 meses.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarCuriosos,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/fondo_curioso.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.75)),
          ),
          _cargando
              ? const Center(child: CircularProgressIndicator())
              : _curiosos.isEmpty
                  ? _buildVacio()
                  : RefreshIndicator(
                      onRefresh: _cargarCuriosos,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(15),
                        itemCount: _curiosos.length,
                        itemBuilder: (context, index) => _buildTarjeta(_curiosos[index]),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text('¡No tienes curiosos aún!', style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text('Crea tu primer curioso', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTarjeta(Curioso curioso) {
    final colorEstado = _colorEstado(curioso);
    final textoEstado = _textoEstado(curioso);
    final tiempo = _tiempoRestante(curioso);
    final expirado = tiempo == 'Expirado';
    final completo = curioso.estaCompleto;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => VerCuriosoScreen(curiosoId: curioso.id!)));
          _cargarCuriosos();
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: colorEstado, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(curioso.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        ),
                        if (completo) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                            child: const Text('Completo', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _eliminarCurioso(curioso)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 5),
                  Text(tiempo, style: TextStyle(color: expirado ? Colors.orange : Colors.grey[600], fontWeight: FontWeight.bold)),
                  const SizedBox(width: 15),
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 5),
                  Text('${curioso.receptores.length}/${curioso.maxReceptores}', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: colorEstado.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: Text(textoEstado, style: TextStyle(color: colorEstado, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}