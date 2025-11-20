const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  // defaultValue: 'http://192.168.0.253:8000',
  // defaultValue: 'http://172.15.208.250:8000',
  // defaultValue: 'http://172.20.10.2:8000',
  defaultValue: 'http://192.168.1.69:8000',
  // defaultValue: 'https://omad-driver.uz',
);
const String apiBaseUrl = '$backendBaseUrl/api';
