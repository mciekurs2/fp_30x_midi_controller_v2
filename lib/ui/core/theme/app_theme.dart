import 'package:flutter/material.dart';

/// The accent (display-P3 #F9278D): the target, a wrong note, an urgent clock.
const accentColor = Color(0xFFF9278D);

/// A correctly played note, against the accent used for a wrong one.
const successColor = Color(0xFF3DDC84);

/// A press the round counts as right: the verdict star, and the readout naming
/// the keys that earned it. Deliberately not [successColor] — the green marks a
/// note *on the staff*, this marks the moment of scoring it.
const hitColor = Colors.amber;

/// Fill for the tonal buttons, against the black background.
const buttonFillColor = Color(0xFF2C2C2C);

/// JollyLodger is condensed with a small x-height, so it is scaled up over
/// whatever the user's own text setting is rather than replacing it.
const textScaleBump = 1.5;

/// A dark theme on black, so the staff reads as ink on an unlit screen.
ThemeData appTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: accentColor,
      tertiary: successColor,
      surface: Colors.black,
      secondaryContainer: buttonFillColor,
      onSecondaryContainer: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.black,
    // Selected chips take the accent; the label resolves to
    // onSecondaryContainer (white), which reads on it.
    chipTheme: base.chipTheme.copyWith(selectedColor: accentColor),
    textTheme: base.textTheme.apply(fontFamily: 'JollyLodger'),
  );
}

/// Applies [textScaleBump] on top of the viewer's own text scale.
Widget withTextScale(BuildContext context, Widget? child) {
  final scaler = MediaQuery.textScalerOf(context);
  return MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scaler.scale(1) * textScaleBump)),
    child: child ?? const SizedBox.shrink(),
  );
}
