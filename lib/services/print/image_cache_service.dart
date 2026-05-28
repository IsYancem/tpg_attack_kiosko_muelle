// lib/services/cache/image_cache_service.dart
// Autor: Abraham Yance
// Fecha: 2025-12-17
// Descripción: Servicio de caché para imágenes de mapas

import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ImageCacheService {
  ImageCacheService._();
  static final ImageCacheService instance = ImageCacheService._();

  // ✅ Caché en memoria: URL -> Bytes
  final Map<String, Uint8List> _cache = {};

  // ✅ URLs en proceso de descarga (evitar duplicados)
  final Map<String, Future<Uint8List?>> _pendingDownloads = {};

  /// Obtiene la imagen desde caché o la descarga si no existe
  Future<Uint8List?> getImage(String url) async {
    // 1) Verificar caché
    if (_cache.containsKey(url)) {
      print('🗺️ [IMAGE_CACHE] Hit: $url');
      return _cache[url];
    }

    // 2) Si ya hay una descarga en progreso, esperar esa
    if (_pendingDownloads.containsKey(url)) {
      print('🗺️ [IMAGE_CACHE] Esperando descarga en progreso: $url');
      return _pendingDownloads[url];
    }

    // 3) Iniciar nueva descarga
    print('🗺️ [IMAGE_CACHE] Descargando: $url');
    final downloadFuture = _downloadImage(url);
    _pendingDownloads[url] = downloadFuture;

    try {
      final bytes = await downloadFuture;
      if (bytes != null) {
        _cache[url] = bytes;
        print('🗺️ [IMAGE_CACHE] Cacheado: $url (${bytes.length} bytes)');
      }
      return bytes;
    } finally {
      _pendingDownloads.remove(url);
    }
  }

  /// Descarga la imagen desde la URL
  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('❌ [IMAGE_CACHE] HTTP ${response.statusCode} para $url');
        return null;
      }
    } catch (e) {
      print('❌ [IMAGE_CACHE] Error descargando $url: $e');
      return null;
    }
  }

  /// Verifica si la imagen está en caché
  bool hasImage(String url) => _cache.containsKey(url);

  /// Obtiene la imagen del caché sin descargar
  Uint8List? getCached(String url) => _cache[url];

  /// Precarga una imagen (fire-and-forget)
  void preload(String url) {
    if (!_cache.containsKey(url) && !_pendingDownloads.containsKey(url)) {
      getImage(url); // Fire-and-forget
    }
  }

  /// Limpia el caché
  void clear() {
    _cache.clear();
    print('🗺️ [IMAGE_CACHE] Caché limpiado');
  }

  /// Limpia una URL específica
  void remove(String url) {
    _cache.remove(url);
  }

  /// Tamaño actual del caché
  int get cacheSize => _cache.length;
}
