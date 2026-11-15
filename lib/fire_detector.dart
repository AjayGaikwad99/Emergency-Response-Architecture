import 'dart:typed_data';
import 'package:camera/camera.dart';

class FireDetector {
  static Map<String, dynamic> detect(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final Uint8List yPlane = cameraImage.planes[0].bytes;
    final Uint8List uPlane = cameraImage.planes[1].bytes;
    final Uint8List vPlane = cameraImage.planes[2].bytes;

    final int yRowStride = cameraImage.planes[0].bytesPerRow;
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

    int firePixels = 0;
    int leftFire = 0;
    int rightFire = 0;
    int totalPixels = width * height;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;
        final int yp = y * yRowStride + x;

        final int Y = yPlane[yp];
        final int U = uPlane[uvIndex];
        final int V = vPlane[uvIndex];

        int r = (Y + (1.370705 * (V - 128))).toInt();
        int g = (Y - (0.337633 * (U - 128)) - (0.698001 * (V - 128))).toInt();
        int b = (Y + (1.732446 * (U - 128))).toInt();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        if (r > 180 && g > 80 && b < 80) {
          firePixels++;
          if (x < width / 2) {
            leftFire++;
          } else {
            rightFire++;
          }
        }
      }
    }

    double fireRatio = firePixels / totalPixels;
    String direction = "Clear";
    if (firePixels > 0) {
      direction = leftFire > rightFire ? "Move Right" : "Move Left";
    }

    return {"ratio": fireRatio, "direction": direction};
  }
}
