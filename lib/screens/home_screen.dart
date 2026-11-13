import 'package:flutter/material.dart';
import 'crear_curioso_screen.dart';
import 'responder_screen.dart';
import 'mis_curiosos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _balancearLogo() {
    if (_controller.isAnimating) return;
    _controller.forward().then((_) {
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4A148C),
              Color(0xFF7B1FA2),
              Color(0xFF9C27B0),
            ],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30), 
                      
                      // LOGO CON ANIMACIÓN
                      GestureDetector(
                        onTap: _balancearLogo,
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _animation.value,
                              child: child,
                            );
                          },
                          child: Image.asset(
                            'assets/images/icono_curioso.png',
                            width: 130, 
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      _buildBoton(context, 'Crear un Curioso', Icons.edit, Colors.deepPurple.shade800, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearCuriosoScreen()));
                      }),
                      const SizedBox(height: 15),
                      
                      _buildBoton(context, 'Responder un Curioso', Icons.search, Colors.blue.shade700, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ResponderScreen()));
                      }),
                      const SizedBox(height: 15),
                      
                      _buildBoton(context, 'Mis Curiosos', Icons.menu_book, Colors.orange.shade800, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MisCuriososScreen()));
                      }),
                      
                      const SizedBox(height: 30),
                      
                      // OPCIÓN DISCRETA DE PREMIUM
                      TextButton(
                        onPressed: () => _mostrarCompraPremium(context),
                        child: const Text(
                          '✨ Curioso Premium',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // FIRMA EN TEXTO MANUSCRITO
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () => _mostrarInfoLegal(context),
                            child: Text(
                              'PK ft alemaniac',
                              style: TextStyle(
                                fontFamily: 'cursive',
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // REGLAS DE USO
            Positioned(
              top: 40,
              right: 60,
              child: GestureDetector(
                onTap: () => _mostrarReglas(context),
                child: Text(
                  'Reglas de uso',
                  style: TextStyle(
                    fontFamily: 'cursive',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // BOTÓN DE AYUDA (?)
            Positioned(
              top: 30,
              right: 15,
              child: IconButton(
                onPressed: () => _mostrarReglas(context),
                icon: const Icon(Icons.help_outline, color: Colors.white, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarReglas(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF8DC),
          title: const Text('Reglas de Uso', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Image.asset('assets/images/regla_1.png', fit: BoxFit.contain),
                  const SizedBox(height: 15),
                  Image.asset('assets/images/regla_2.png', fit: BoxFit.contain),
                  const SizedBox(height: 15),
                  Image.asset('assets/images/regla_3.png', fit: BoxFit.contain),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Colors.deepPurple)),
            ),
          ],
        );
      },
    );
  }

  void _mostrarCompraPremium(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('✨ Curioso Premium', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Desbloquea todo el potencial de Curioso:'),
              SizedBox(height: 10),
              Text('• Crea curiosos ilimitados'),
              Text('• Edita preguntas sin límites'),
              Text('• Comparte con más de 6 receptores'),
              SizedBox(height: 20),
              Text('Precio:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('\$1,99 USD cada 6 meses', style: TextStyle(fontSize: 16, color: Colors.deepPurple)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              onPressed: () {
                Navigator.pop(context);
                _mostrarBienvenidaPremium(context);
              },
              child: const Text('Comprar por \$1,99'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarBienvenidaPremium(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¡Bienvenido a Curioso Premium! 🎉', style: TextStyle(color: Colors.deepPurple)),
          content: const Text('Tu compra se ha realizado con éxito. Ya puedes disfrutar de todos los beneficios sin límites.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Empezar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarInfoLegal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Información de Curioso', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('¿Quiénes somos?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const Text('Curioso es una aplicación creada por PK ft Alemaniac para conectar a las personas a través de preguntas sinceras.'),
                const SizedBox(height: 15),
                const Text('Contacto', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const Text('Correo: alemaniac22@gmail.com'), 
                const SizedBox(height: 15),
                const Text('Políticas de Privacidad y Términos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const Text('Al usar esta app, aceptas que tus respuestas serán compartidas de forma anónima con el creador del curioso y otros participantes. No recopilamos datos sensibles de geolocalización.'),
                const SizedBox(height: 15),
                const Text('Política de Reembolsos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const Text('Al ser una app de versión Free con opción a Premium, las compras de Premium no son reembolsables, salvo que la ley local de tu país exija lo contrario.'),
                const SizedBox(height: 15),
                const Text('Copyright', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const Text('Las ilustraciones y el diseño de Curioso son propiedad de sus creadores. Las imágenes generadas por IA son de uso libre según las leyes actuales.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBoton(BuildContext context, String titulo, IconData icono, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icono, color: Colors.white),
        label: Text(
          titulo, 
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
          shadowColor: Colors.black45,
        ),
      ),
    );
  }
}