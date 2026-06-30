/// A parsed geographic coordinate.
class LatLng {
  const LatLng(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Parses coordinates pasted from Google Maps. Accepts the two forms a user is
/// likely to copy:
///
/// - a bare **`lat, lng`** pair — `24.7136, 46.6753` (right-click a spot →
///   click the coordinates to copy this);
/// - a desktop Maps **URL** containing an `@lat,lng,zoom` segment —
///   `https://www.google.com/maps/@24.7136,46.6753,17z`.
///
/// Short share links (`maps.app.goo.gl/…`) carry no coordinates in the text and
/// are **not** supported — they'd need a network redirect to resolve. Returns
/// `null` when nothing parseable / out of range is found.
LatLng? parseLatLng(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  // Prefer an explicit `@lat,lng` from a Maps URL when present.
  final atMatch = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(text);
  final source = atMatch != null ? atMatch.group(0)!.substring(1) : text;

  final pair = RegExp(r'(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)').firstMatch(source);
  if (pair == null) return null;

  final lat = double.tryParse(pair.group(1)!);
  final lng = double.tryParse(pair.group(2)!);
  if (lat == null || lng == null) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return LatLng(lat, lng);
}
