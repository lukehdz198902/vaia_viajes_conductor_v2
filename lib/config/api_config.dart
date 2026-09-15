class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://app.vaia.com.mx/apis_v2/api/Conductor',
  );

  static const String hostBaseUrl = String.fromEnvironment(
    'HOST_BASE_URL',
    defaultValue: 'https://app.vaia.com.mx/apis_v2',
  );

  static const String conductorEndpoint = '/Conductor';
  static const Duration timeout = Duration(seconds: 30);
  static const Duration shortTimeout = Duration(seconds: 10);

  static String get conductorBaseUrl =>
      baseUrl.endsWith('/Conductor') ? baseUrl : '$baseUrl$conductorEndpoint';

  static String get apiRoot =>
      baseUrl.endsWith('/Conductor') ? baseUrl.substring(0, baseUrl.length - '/Conductor'.length) : baseUrl;

  static String get servicioHubUrl => '$hostBaseUrl/hubs/servicio';
  static String get chatHubUrl => '$hostBaseUrl/hubs/chat';
  static String get soporteHubUrl => '$hostBaseUrl/hubs/soporte';
}