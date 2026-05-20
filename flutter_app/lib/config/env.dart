class Env {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:3000/api',
  );
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );
  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );
}
// class Env {
//   static const String apiUrl = String.fromEnvironment(
//     'API_URL',
//     defaultValue: 'http://10.1.10.133:3000/api',  // ✅ your PC's IP
//   );
//     static const String cloudinaryCloudName = String.fromEnvironment(
//     'CLOUDINARY_CLOUD_NAME',
//     defaultValue: '',
//   );
//   static const String cloudinaryUploadPreset = String.fromEnvironment(
//     'CLOUDINARY_UPLOAD_PRESET',
//     defaultValue: '',
//   );

// }