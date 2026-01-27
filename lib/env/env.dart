import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'GENIUS_API_KEY', obfuscate: true)
  static final String geniusApiKey = _Env.geniusApiKey;

  @EnviedField(varName: 'PIXABAY_API_KEY', obfuscate: true)
  static final String pixabayApiKey = _Env.pixabayApiKey;

  @EnviedField(varName: 'UNSPLASH_ACCESS_KEY', obfuscate: true)
  static final String unsplashAccessKey = _Env.unsplashAccessKey;
}
