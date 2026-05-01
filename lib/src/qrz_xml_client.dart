/// QRZ.com XML Data API client — callsign lookups.
///
/// Authenticates with username + password to obtain a session key, then
/// looks up callsign data.  The session key is cached and automatically
/// refreshed when the server reports it as expired.
///
/// Requires a QRZ.com XML subscription (separate from the Logbook API key).
/// See: https://www.qrz.com/docs/xml/current_spec.html
library;

import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// Information about a licensed amateur radio station from QRZ.com.
class CallsignInfo {
  final String call;
  final String firstName;
  final String lastName;
  final String address;
  final String city;
  final String county;
  final String state;
  final String country;
  final String grid;
  final String licenseClass;
  final String email;
  final String url;
  final String cqZone;
  final String ituZone;
  final String dxcc;
  final String iota;
  final String qslMgr;
  final String? imageUrl;

  const CallsignInfo({
    required this.call,
    this.firstName = '',
    this.lastName = '',
    this.address = '',
    this.city = '',
    this.county = '',
    this.state = '',
    this.country = '',
    this.grid = '',
    this.licenseClass = '',
    this.email = '',
    this.url = '',
    this.cqZone = '',
    this.ituZone = '',
    this.dxcc = '',
    this.iota = '',
    this.qslMgr = '',
    this.imageUrl,
  });

  /// Full name — "First Last", "First", "Last", or empty.
  String get fullName {
    final parts = [firstName, lastName].where((s) => s.isNotEmpty).toList();
    return parts.join(' ');
  }

  /// Single-line location summary — e.g. "Newington, CT, USA".
  String get locationLine {
    final parts = [city, state, country].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }
}

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

class QrzXmlException implements Exception {
  final String message;
  const QrzXmlException(this.message);

  @override
  String toString() => 'QrzXmlException: $message';
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

/// Client for the QRZ.com XML Data API.
class QrzXmlClient {
  final String username;
  final String password;
  final http.Client _http;
  final bool _ownedClient;

  String? _sessionKey;

  static final _base = Uri.parse('https://xmldata.qrz.com/xml/current/');

  QrzXmlClient({
    required this.username,
    required this.password,
    http.Client? httpClient,
  })  : _http = httpClient ?? http.Client(),
        _ownedClient = httpClient == null;

  /// Look up a callsign.  Authenticates automatically if needed.
  /// Throws [QrzXmlException] on errors.
  Future<CallsignInfo> lookupCallsign(String callsign) async {
    await _ensureSession();
    return _doLookup(callsign);
  }

  Future<CallsignInfo> _doLookup(String callsign) async {
    final uri = _base.replace(
      query: 's=${_sessionKey!};callsign=${callsign.toUpperCase()}',
    );
    final resp = await _http.get(uri);
    final body = resp.body;

    // Session expired — refresh and retry once
    final sessionError = _tag(body, 'Error');
    if (sessionError != null &&
        (sessionError.contains('Session Timeout') ||
            sessionError.contains('Invalid session key') ||
            sessionError.contains('Username'))) {
      _sessionKey = null;
      await _ensureSession();
      return _doLookup(callsign);
    }

    // API-level error (e.g. callsign not found)
    final error = sessionError;
    if (error != null) throw QrzXmlException(error);

    final call = _tag(body, 'call');
    if (call == null) throw QrzXmlException('Callsign not found');

    return CallsignInfo(
      call: call,
      firstName: _tag(body, 'fname') ?? '',
      lastName: _tag(body, 'name') ?? '',
      address: _tag(body, 'addr1') ?? '',
      city: _tag(body, 'addr2') ?? '',
      county: _tag(body, 'county') ?? '',
      state: _tag(body, 'state') ?? '',
      country: _tag(body, 'country') ?? '',
      grid: _tag(body, 'grid') ?? '',
      licenseClass: _tag(body, 'class') ?? '',
      email: _tag(body, 'email') ?? '',
      url: _tag(body, 'url') ?? '',
      cqZone: _tag(body, 'cqzone') ?? '',
      ituZone: _tag(body, 'ituzone') ?? '',
      dxcc: _tag(body, 'country') ?? '',  // QRZ 'country' field = DXCC entity name
      iota: _tag(body, 'iota') ?? '',
      qslMgr: _tag(body, 'qslmgr') ?? '',
      imageUrl: _tag(body, 'image'),
    );
  }

  Future<void> _ensureSession() async {
    if (_sessionKey != null) return;

    final uri = _base.replace(
      query:
          'username=${Uri.encodeComponent(username)};password=${Uri.encodeComponent(password)};agent=openRigConsole-0.1',
    );
    final resp = await _http.get(uri);
    final body = resp.body;

    final key = _tag(body, 'Key');
    if (key == null || key.isEmpty) {
      final error = _tag(body, 'Error') ?? 'Authentication failed';
      throw QrzXmlException(error);
    }
    _sessionKey = key;
  }

  void dispose() {
    if (_ownedClient) _http.close();
  }

  /// Extract the text content of a single XML tag by name.
  static String? _tag(String xml, String name) {
    final start = xml.indexOf('<$name>');
    if (start < 0) return null;
    final end = xml.indexOf('</$name>', start);
    if (end < 0) return null;
    final value = xml.substring(start + name.length + 2, end).trim();
    return value.isEmpty ? null : value;
  }
}
