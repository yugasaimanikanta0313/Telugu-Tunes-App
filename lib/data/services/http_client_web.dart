import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Lets the browser store the HttpOnly local development session cookie.
http.Client createHttpClient() => BrowserClient()..withCredentials = true;
