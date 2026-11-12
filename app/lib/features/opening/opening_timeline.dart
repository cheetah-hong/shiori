import 'package:flutter/animation.dart';

/// The opening's whole length; every key below is a fraction of it.
const Duration openingLength = Duration(milliseconds: 1200);

/// One key of a track: at [at] (0–1 of [openingLength]) the value is [value].
typedef Keyframe = ({double at, double value});

/// Value of a keyed track at [t], eased between neighbouring keys (CSS
/// keyframes with the default `ease`).
double track(List<Keyframe> keys, double t) {
  if (t <= keys.first.at) return keys.first.value;
  for (var i = 1; i < keys.length; i++) {
    final (a, b) = (keys[i - 1], keys[i]);
    if (t > b.at) continue;
    final local = Curves.ease.transform((t - a.at) / (b.at - a.at));
    return a.value + (b.value - a.value) * local;
  }
  return keys.last.value;
}

// 0.00–0.30 s the page alone (the launch screen); 0.30–0.62 s the camera
// corners close in from 1.7×.
const frameOpacity = <Keyframe>[(at: 0.25, value: 0), (at: 0.45, value: 1)];
const frameScale = <Keyframe>[
  (at: 0.25, value: 1.7),
  (at: 0.45, value: 0.94),
  (at: 0.52, value: 1),
];

// ~0.53 s a short flash while the page is pressed.
const flashOpacity = <Keyframe>[
  (at: 0.44, value: 0),
  (at: 0.48, value: 1),
  (at: 0.62, value: 0),
];
const bookScale = <Keyframe>[
  (at: 0.44, value: 1),
  (at: 0.48, value: 0.95),
  (at: 0.56, value: 1),
  (at: 0.64, value: 0.9),
];
const bookOpacity = <Keyframe>[(at: 0.56, value: 1), (at: 0.64, value: 0)];

// 0.65–0.94 s し is written in one stroke, then lands once (탁).
const shiDrawn = <Keyframe>[(at: 0.54, value: 0), (at: 0.78, value: 1)];
const shiWeight = <Keyframe>[
  (at: 0.78, value: 1),
  (at: 0.84, value: 70 / 58),
  (at: 0.90, value: 1),
];

// 1.03–1.20 s the layer lifts off and 홈 shows through.
const layerOpacity = <Keyframe>[(at: 0.86, value: 1), (at: 1, value: 0)];
const layerScale = <Keyframe>[(at: 0.86, value: 1), (at: 1, value: 1.04)];
