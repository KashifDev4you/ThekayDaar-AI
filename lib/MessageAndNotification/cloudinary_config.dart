import 'package:ali_app/services/env_config.dart';

class CloudinaryConfig {
  /// Your Cloudinary cloud name (public identifier).
  static String get cloudName => EnvConfig.get('CLOUDINARY_CLOUD_NAME');

  /// Unsigned upload preset for client-side uploads.
  static String get uploadPreset => EnvConfig.get('CLOUDINARY_UPLOAD_PRESET');
}
