import 'package:outlet_app/constants.dart';

/// Builds an absolute, percent-encoded URL for media files returned by the API.
/// Handles values that already include a scheme as well as relative paths
/// (with or without a leading slash).
String? resolveMediaUrl(String? rawPath) {
  if (rawPath == null) return null;
  final trimmed = rawPath.trim();
  if (trimmed.isEmpty) return null;

  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    try {
      return Uri.parse(trimmed).toString();
    } catch (_) {
      return Uri.encodeFull(trimmed);
    }
  }

  try {
    final baseUri = Uri.parse(BASE_URL);
    final normalized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    final segments =
        normalized.split('/').where((segment) => segment.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      final first = segments.first.toLowerCase();
      if (first != 'media' && first != 'static') {
        segments.insert(0, 'media');
      }
    }
    final mergedSegments = [
      ...baseUri.pathSegments,
      ...segments,
    ];
    return baseUri.replace(pathSegments: mergedSegments).toString();
  } catch (_) {
    return trimmed;
  }
}
