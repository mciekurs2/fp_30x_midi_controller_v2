import '../../domain/models/music_key.dart';
import '../../domain/models/note_value.dart';
import '../../domain/models/pitch.dart';
import '../../domain/models/song.dart';

/// A `.song` file that could not be read. Charts are transcribed by hand, so a
/// typo is expected rather than exceptional — it carries enough to point at the
/// offending token instead of surfacing as a `RangeError` from deep in parsing.
class SongFormatException implements Exception {
  const SongFormatException(this.reason, {required this.line, this.token});

  final String reason;

  /// 1-based line number in the source file.
  final int line;
  final String? token;

  @override
  String toString() {
    final where = token == null ? '' : ' at "$token"';
    return 'SongFormatException: $reason (line $line$where)';
  }
}

final RegExp _pitch = RegExp(r'^[A-Ga-g][#bn]?-?\d+$');
const _separators = {' ', '\t', '|'};

/// Parses a `.song` file. Header lines are `key: value` (`title`, `key`,
/// `time`, `barlines`); `RH:`/`LH:` lines are voices. Accidentals are
/// key-implicit — a note diatonic to the signature is written bare (`F4` in D
/// major means F♯), and `#`/`b`/`n` only mark a departure from it.
///
/// Throws [SongFormatException] on a malformed voice token.
Song parseSong(String text) {
  var title = 'Untitled';
  MusicKey? key;
  var beatsPerBar = 4;
  var beatUnit = 4;
  var barlines = true;
  final voiceLines = <Hand, List<({int number, String text})>>{
    Hand.right: [],
    Hand.left: [],
  };

  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final upper = line.toUpperCase();
    final hand = switch (true) {
      _ when upper.startsWith('RH:') => Hand.right,
      _ when upper.startsWith('LH:') => Hand.left,
      _ => null,
    };
    if (hand != null) {
      voiceLines[hand]!.add((number: i + 1, text: line.substring(3)));
      continue;
    }

    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    final field = line.substring(0, colon).trim().toLowerCase();
    final value = line.substring(colon + 1).trim();
    switch (field) {
      case 'title':
        title = value;
      case 'key':
        key = _parseKey(value);
      case 'time':
        (beatsPerBar, beatUnit) = _parseTime(value);
      case 'barlines':
        barlines = !const {
          'off',
          'no',
          'none',
          'false',
        }.contains(value.toLowerCase());
    }
  }

  SongVoice? voice(Hand hand) {
    final source = voiceLines[hand]!;
    if (source.isEmpty) return null;
    return [
      for (final line in source)
        for (final token in _tokenize(line.text))
          _parseEvent(token, key, line.number),
    ];
  }

  return Song(
    title: title,
    key: key,
    beatsPerBar: beatsPerBar,
    beatUnit: beatUnit,
    rh: voice(Hand.right),
    lh: voice(Hand.left),
    barlines: barlines,
  );
}

MusicKey? _parseKey(String value) {
  final parts = value.split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return null;
  final tonic = parts.first;
  final minor = parts.length > 1 && parts[1].toLowerCase().startsWith('min');
  final letter = letterNames.indexOf(tonic[0].toUpperCase());
  if (letter < 0) return null;
  var pitchClass = naturalPitches[letter];
  if (tonic.length > 1) {
    pitchClass += switch (tonic[1]) {
      '#' => 1,
      'b' => -1,
      _ => 0,
    };
  }
  pitchClass = mod(pitchClass, 12);
  return minor ? MusicKey.minor(pitchClass) : MusicKey.major(pitchClass);
}

(int, int) _parseTime(String value) {
  final parts = value.split('/');
  final top = int.tryParse(parts.first.trim()) ?? 4;
  final bottom = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 4 : 4;
  return (top, bottom);
}

/// Splits a voice into event tokens, keeping a bracketed chord (and its
/// trailing duration) whole while dropping barlines and whitespace.
List<String> _tokenize(String voice) {
  final tokens = <String>[];
  var i = 0;
  while (i < voice.length) {
    if (_separators.contains(voice[i])) {
      i++;
      continue;
    }
    var j = i;
    if (voice[i] == '[') {
      j = voice.indexOf(']', i) + 1;
      if (j == 0) j = voice.length; // unterminated: take the rest, then reject
    }
    while (j < voice.length && !_separators.contains(voice[j])) {
      j++;
    }
    tokens.add(voice.substring(i, j));
    i = j;
  }
  return tokens;
}

SongEvent _parseEvent(String token, MusicKey? key, int line) {
  if (token.startsWith('[')) {
    final close = token.indexOf(']');
    if (close < 0) {
      throw SongFormatException('unterminated chord', line: line, token: token);
    }
    final (value, dotted) = _parseDuration(token.substring(close + 1));
    final notes = [
      for (final part in token.substring(1, close).split(RegExp(r'\s+')))
        if (part.isNotEmpty) _parseNote(part, key, line),
    ];
    if (notes.isEmpty) {
      throw SongFormatException('empty chord', line: line, token: token);
    }
    return SongEvent(notes: notes, value: value, dotted: dotted);
  }

  if (token[0].toUpperCase() == 'R') {
    final (value, dotted) = _parseDuration(token.substring(1));
    return SongEvent(notes: const [], value: value, dotted: dotted);
  }

  // A pitch runs up to its duration suffix, so split there and validate both.
  final split = token.indexOf(RegExp(r'[whqes.]', caseSensitive: false), 1);
  final pitch = split < 0 ? token : token.substring(0, split);
  final (value, dotted) = _parseDuration(
    split < 0 ? '' : token.substring(split),
  );
  return SongEvent(
    notes: [_parseNote(pitch, key, line)],
    value: value,
    dotted: dotted,
  );
}

SongNote _parseNote(String text, MusicKey? key, int line) {
  if (!_pitch.hasMatch(text)) {
    throw SongFormatException(
      'expected a pitch like C4, F#4 or Eb3',
      line: line,
      token: text,
    );
  }
  final letter = letterNames.indexOf(text[0].toUpperCase());
  var i = 1;
  final written = switch (text[i]) {
    '#' => Accidental.sharp,
    'b' => Accidental.flat,
    'n' => Accidental.natural,
    _ => null,
  };
  if (written != null) i++;
  final octave = int.parse(text.substring(i)); // the regex guarantees digits

  // An explicit accidental sets the pitch and is drawn; a bare note takes the
  // signature's alteration and draws nothing (the signature has said it).
  final alteration = switch (written) {
    Accidental.sharp => 1,
    Accidental.flat => -1,
    Accidental.natural => 0,
    null => key?.alterationForLetter(letter) ?? 0,
  };
  return SongNote(
    midi: (octave + 1) * 12 + naturalPitches[letter] + alteration,
    letter: letter,
    octave: octave,
    drawn: written,
  );
}

(NoteValue, bool) _parseDuration(String suffix) {
  var value = NoteValue.crotchet;
  var dotted = false;
  for (final char in suffix.split('')) {
    switch (char.toLowerCase()) {
      case 'w':
        value = NoteValue.semibreve;
      case 'h':
        value = NoteValue.minim;
      case 'q':
        value = NoteValue.crotchet;
      case 'e':
        value = NoteValue.quaver;
      case 's':
        value = NoteValue.semiquaver;
      case '.':
        dotted = true;
    }
  }
  return (value, dotted);
}
