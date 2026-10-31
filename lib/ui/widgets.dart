import 'package:flutter/material.dart';

import '../app/theme.dart';

class BigButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool reward;
  const BigButton(this.label,
      {super.key, this.onTap, this.primary = true, this.reward = false});

  @override
  Widget build(BuildContext context) {
    final bg = reward ? Colors.white : (primary ? C.primary : C.panel);
    final fg = reward ? C.rewardText : (primary ? Colors.white : C.text);
    final shadow = reward ? C.reward : (primary ? C.primaryShadow : C.border);
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56, minWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: reward ? C.reward : shadow, width: 2),
            boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 4))],
          ),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (reward) const AdBadge(),
            if (reward) const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: fg, fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

class AdBadge extends StatelessWidget {
  const AdBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
            color: C.adBadge, borderRadius: BorderRadius.circular(5)),
        child: const Text('AD',
            style: TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
      );
}

class Stars extends StatelessWidget {
  final int n;
  final double size;
  const Stars(this.n, {super.key, this.size = 16});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Icon(i < n ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size, color: i < n ? const Color(0xFFFFB800) : C.border),
        ],
      );
}

/// Placeholder for the adaptive banner slot.
class BannerSlot extends StatelessWidget {
  final bool hidden;
  const BannerSlot({super.key, this.hidden = false});
  @override
  Widget build(BuildContext context) => hidden
      ? const SizedBox.shrink()
      : Container(
          height: 50,
          color: const Color(0xFFEDE3D3),
          alignment: Alignment.center,
          child: const Text('Banner ad (test)',
              style: TextStyle(color: C.text2, fontSize: 12)),
        );
}
