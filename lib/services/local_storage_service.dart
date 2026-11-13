import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalStorageService {
  static const String _keyUuid = 'dispositivo_uuid';
  static const String _keyNombre = 'usuario_nombre';
  static const String _keyEmail = 'usuario_email';
  static const String _keyContadorCuriosos = 'contador_curiosos';
  static const String _keyMisCuriosos = 'mis_curiosos_ids';

  // Obtener o crear un UUID único para este dispositivo
  static Future<String> obtenerUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString(_keyUuid);
    if (uuid == null) {
      uuid = const Uuid().v4();
      await prefs.setString(_keyUuid, uuid);
    }
    return uuid;
  }

  // Guardar nombre del usuario
  static Future<void> guardarNombre(String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNombre, nombre);
  }

  // Obtener nombre del usuario
  static Future<String?> obtenerNombre() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNombre);
  }

  // Guardar email
  static Future<void> guardarEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
  }

  // Obtener email
  static Future<String?> obtenerEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  // --- LÓGICA DE LA VERSIÓN GRATUITA ---
  
  // Verifica si el usuario puede crear otro curioso (límite de 3)
  static Future<bool> puedeCrearCurioso() async {
    final prefs = await SharedPreferences.getInstance();
    final contador = prefs.getInt(_keyContadorCuriosos) ?? 0;
    return contador < 3; 
  }

  // Suma 1 al contador cuando crea un curioso
  static Future<void> incrementarContador() async {
    final prefs = await SharedPreferences.getInstance();
    final contador = prefs.getInt(_keyContadorCuriosos) ?? 0;
    await prefs.setInt(_keyContadorCuriosos, contador + 1);
  }

  // --- MANEJO DE LA LISTA LOCAL DE CURIOSOS ---

  // Guardar el ID de un curioso creado localmente
  static Future<void> agregarCuriosoLocal(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_keyMisCuriosos) ?? [];
    if (!lista.contains(id)) {
      lista.add(id);
      await prefs.setStringList(_keyMisCuriosos, lista);
    }
  }

  // Eliminar un curioso de la lista local
  static Future<void> eliminarCuriosoLocal(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_keyMisCuriosos) ?? [];
    lista.remove(id);
    await prefs.setStringList(_keyMisCuriosos, lista);
  }

  // Obtener la lista de IDs de mis curiosos
  static Future<List<String>> obtenerMisCuriososIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyMisCuriosos) ?? [];
  }

  // Marcar un curioso como contestado (para no salir en la lista de pendientes)
  static Future<void> marcarComoContestado(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('contestado_$id', true);
  }

  // Verificar si ya fue contestado
  static Future<bool> fueContestado(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('contestado_$id') ?? false;
  }
}