import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import 'contestar_ronda_screen.dart';

class ResponderScreen extends StatefulWidget {
  const ResponderScreen({super.key});

  @override
  State<ResponderScreen> createState() => _ResponderScreenState();
}

class _ResponderScreenState extends State<ResponderScreen> {
  final TextEditingController _idController = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _buscarCurioso() async {
    final id = _idController.text.trim();

    if (id.isEmpty) {
      _mostrarMensaje('Ingresa el ID del curioso');
      return;
    }

    setState(() => _cargando = true);

    final curioso = await PocketBaseService.obtenerCurioso(id);

    setState(() => _cargando = false);

    if (curioso == null) {
      _mostrarMensaje('No se encontró el curioso');
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContestarRondaScreen(curiosoId: id),
        ),
      );
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Responder un Curioso',
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
              : Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 20,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search,
                            size: 80, color: Colors.deepPurple),
                        const SizedBox(height: 20),
                        const Text(
                          'Ingresa el ID del curioso',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Pega aquí el ID que te compartió el dueño',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        TextField(
                          controller: _idController,
                          decoration: InputDecoration(
                            labelText: 'ID del curioso',
                            hintText: 'Ej: abc123def456',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.vpn_key),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onSubmitted: (_) => _buscarCurioso(),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _buscarCurioso,
                            icon: const Icon(Icons.search, color: Colors.white),
                            label: const Text(
                              'Buscar Curioso',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}