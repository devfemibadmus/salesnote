import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('android_icon_padded.png');
  if (!file.existsSync()) {
    print('android_icon_padded.png not found!');
    return;
  }
  
  final original = img.decodeImage(file.readAsBytesSync());
  if (original == null) {
     print('Failed to decode image');
     return;
  }
  
  // Adaptive icons foreground sizes (in px):
  // mdpi: 108x108
  // hdpi: 162x162
  // xhdpi: 216x216
  // xxhdpi: 324x324
  // xxxhdpi: 432x432
  
  final sizes = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
  };
  
  for (final entry in sizes.entries) {
    final density = entry.key;
    final size = entry.value;
    
    // Resize for adaptive foreground
    final resized = img.copyResize(original, width: size, height: size, interpolation: img.Interpolation.average);
    
    final fgName = 'android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png';
    File(fgName)
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(resized));
      
    // Resize legacy launcher icon (48x48 base)
    // Legacy icons sizes (in px):
    // mdpi: 48x48
    // hdpi: 72x72
    // xhdpi: 96x96
    // xxhdpi: 144x144
    // xxxhdpi: 192x192
    
    final legacySize = (48 * (size / 108)).round();
    final legacyResized = img.copyResize(original, width: legacySize, height: legacySize, interpolation: img.Interpolation.average);
    
    final legacyName = 'android/app/src/main/res/mipmap-$density/ic_launcher.png';
    File(legacyName)
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(legacyResized));
      
    // Duplicate legacy into ic_launcher_round.png for older APIs that support round but not v26 adaptive
    final roundName = 'android/app/src/main/res/mipmap-$density/ic_launcher_round.png';
    File(roundName)
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(legacyResized));
      
    print('Generated $density sizes ($size x $size)');
  }
  print('Successfully overwritten all Android launcher icons!');
}
