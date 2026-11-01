/// Damped spring that stays stable however long a frame takes.
///
/// A single Euler step with a large `dt` (app resumed, GC pause, slow frame)
/// makes a stiff spring diverge, so time is capped per frame and integrated
/// in small fixed substeps.
class Spring {
  final double stiffness, damping;
  double value = 0, velocity = 0;
  Spring({this.stiffness = 520, this.damping = 16});

  static const maxFrame = 1 / 15;
  static const step = 1 / 240;

  void update(double dt, double target) {
    var left = dt.clamp(0.0, maxFrame);
    while (left > 0) {
      final h = left < step ? left : step;
      velocity += ((target - value) * stiffness - velocity * damping) * h;
      value += velocity * h;
      left -= h;
    }
  }

  void reset() {
    value = 0;
    velocity = 0;
  }
}
