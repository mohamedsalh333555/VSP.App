import 'dart:io';
import 'package:image/image.dart';

void main() async {
  final file = File('assets/images/logo.png');
  if (!file.existsSync()) {
    print('Error: logo.png not found');
    return;
  }
  
  final bytes = file.readAsBytesSync();
  final original = decodeImage(bytes);
  if (original == null) {
    print('Failed to decode image');
    return;
  }
  
  print('Loaded original image: ${original.width}x${original.height}');
  
  // Make completely black or very dark background pixels transparent
  for (var p in original) {
    if (p.r < 15 && p.g < 15 && p.b < 15) {
      p.setRgba(0, 0, 0, 0);
    }
  }
  
  // Add 30% padding
  int padX = (original.width * 0.3).toInt();
  int padY = (original.height * 0.3).toInt();
  int newWidth = original.width + padX * 2;
  int newHeight = original.height + padY * 2;
  
  print('Creating padded image: ${newWidth}x${newHeight}');
  var padded = Image(width: newWidth, height: newHeight, numChannels: 4);
  
  // Draw the original image centered into the padded image
  compositeImage(padded, original, dstX: padX, dstY: padY);
  
  // Save output
  final outBytes = encodePng(padded);
  final outFile = File('assets/images/logo_foreground.png');
  outFile.writeAsBytesSync(outBytes);
  
  print('Successfully created logo_foreground.png!');
}
