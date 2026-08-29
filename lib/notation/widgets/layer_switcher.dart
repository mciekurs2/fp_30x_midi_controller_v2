import 'package:flutter/material.dart';

/// A crossfade for an [AnimatedSwitcher] whose entries never collide.
///
/// `AnimatedSwitcher.defaultTransitionBuilder` keys its fade on the child's
/// own key, and `KeyedSubtree.wrap` keys each entry on *that* where it has one
/// — so a child that comes back while the one before it is still fading out
/// puts two identical keys in the switcher's `Stack`, and it asserts:
/// *Duplicate keys found*. Every layer here is keyed on what it draws, and
/// played fast enough they all fold back on themselves: a clef returning two
/// targets later, the readout going empty between two presses of the same key.
///
/// This fade carries no key, so each entry falls back to the switcher's own
/// child number, which is unique by construction. Any custom
/// `transitionBuilder` that does the same is equally safe — the default is the
/// one to avoid.
Widget fadeLayer(Widget child, Animation<double> animation) =>
    FadeTransition(opacity: animation, child: child);
