import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('appstore.jpg');
  final original = img.decodeImage(file.readAsBytesSync());
  if (original == null) {
     print('Failed to decode image');
     return;
  }
  
  // Create a new image that is 1.6x larger to give ample padding
  final newSize = (original.width * 1.6).round();
  
  final newImage = img.Image(width: newSize, height: newSize);
  
  // Get background color from pixel at origin (0,0)
  final bgColor = original.getPixel(0, 0);
  
  // Fill background
  img.fill(newImage, color: bgColor);
  
  // Draw original image exactly in the center
  final dstX = (newSize - original.width) ~/ 2;
  final dstY = (newSize - original.height) ~/ 2;
  img.compositeImage(newImage, original, dstX: dstX, dstY: dstY);
  
  // Save result
  final out = File('android_icon_padded.png');
  out.writeAsBytesSync(img.encodePng(newImage));
  print('Successfully created android_icon_padded.png ($newSize x $newSize)');
}
