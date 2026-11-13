import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/curioso.dart';

class PocketBaseService {
  // La URL de tu PocketBase (asegúrate de que sea la correcta)
  static const String baseUrl = 'https://contestar.alemaniac.online';
  static const String coleccion = 'curiosos';

  // Crear un nuevo curioso
  static Future<Curioso?> crearCurioso(Curioso curioso) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/collections/$coleccion/records'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(curioso.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Curioso.fromJson(data, data['id']);
      } else {
        print('Error al crear: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Excepción al crear: $e');
      return null;
    }
  }

  // Obtener un curioso por su ID
  static Future<Curioso?> obtenerCurioso(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/$coleccion/records/$id'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Curioso.fromJson(data, data['id']);
      } else {
        return null;
      }
    } catch (e) {
      print('Excepción al obtener: $e');
      return null;
    }
  }

  // Actualizar un curioso (respuestas, estado, etc.)
  static Future<bool> actualizarCurioso(Curioso curioso) async {
    if (curioso.id == null) return false;
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/collections/$coleccion/records/${curioso.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(curioso.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Excepción al actualizar: $e');
      return false;
    }
  }

  // Listar los curiosos creados por un usuario (por su UUID)
  static Future<List<Curioso>> listarCuriososPorId(String creadorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/$coleccion/records?filter=(creadorId="$creadorId")'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['items'] ?? [];
        return items.map((item) => Curioso.fromJson(item, item['id'])).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Excepción al listar: $e');
      return [];
    }
  }

  // Eliminar un curioso
  static Future<bool> eliminarCurioso(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/collections/$coleccion/records/$id'),
      );
      return response.statusCode == 204;
    } catch (e) {
      print('Excepción al eliminar: $e');
      return false;
    }
  }
}