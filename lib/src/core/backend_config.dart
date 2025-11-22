const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  // defaultValue: 'http://192.168.100.188:8000', // ofis
  // defaultValue: 'http://172.15.208.250:8000',
  // defaultValue: 'http://172.20.10.2:8000', // tel
  // defaultValue: 'http://192.168.1.69:8000', //uy
  defaultValue: 'https://omad-driver.uz',
);
const String apiBaseUrl = '$backendBaseUrl/api';
