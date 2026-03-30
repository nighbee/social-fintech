/// Заметное масштабирование пинов: сильнее растут при сильном приближении (в т.ч. z > 18.5).
double mapMarkerSizeMultiplier(double zoom) {
  const minZ = 9.0;
  const refZ = 14.5;
  const maxZ = 20.5;
  const minM = 0.55;
  const maxM = 2.25;
  final z = zoom.clamp(minZ, maxZ);
  if (z <= refZ) {
    final t = (z - minZ) / (refZ - minZ);
    return minM + (1.0 - minM) * t;
  }
  final t = (z - refZ) / (maxZ - refZ);
  return 1.0 + (maxM - 1.0) * t;
}
