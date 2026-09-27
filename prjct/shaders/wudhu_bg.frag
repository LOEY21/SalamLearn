#version 460 core

#include <flutter/runtime_effect.glsl>

// Wudhu washroom: the painted plants sway in a light draught.
// Two layers so the wall never moves: uBg is the room with the leaves
// painted out, uLeaves the leaves alone (premultiplied alpha), drawn over
// it with a displacement.
// uPlant: r = which plant (sway phase), g = how strongly it moves,
// b = how much the pixel bends (0 at the root, 1 at the leaf tips).

uniform vec2 uSize;
uniform vec2 uImg;
uniform float uTime;
uniform sampler2D uBg;
uniform sampler2D uLeaves;
uniform sampler2D uPlant;

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(17.1, 9.2);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float t = uTime;

  // BoxFit.cover, centred (matches Image.asset(fit: BoxFit.cover)).
  float s = max(uSize.x / uImg.x, uSize.y / uImg.y);
  vec2 d = uImg * s;
  vec2 uv = (p - (uSize - d) * 0.5) / d;

  vec3 col = texture(uBg, uv).rgb;
  vec4 pm = texture(uPlant, uv);
  float bend = pm.b;
  vec2 suv = uv;
  float lit = 1.0;
  if (bend > 0.002) {
    float phase = pm.r * 25.0;
    float amp = pm.g;
    // Slow gusts, each plant on its own beat.
    float gust = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 0.37 + phase * 0.2)) *
        (0.6 + 0.4 * sin(t * 0.21 + 1.3));
    // Broad, slow swing plus a quicker secondary sway on top.
    float sway = gust * (sin(t * 0.9 + phase) + 0.3 * sin(t * 2.1 + phase * 1.3));
    vec2 q = uv * uImg / 70.0;
    vec2 flutter = vec2(
        fbm(q + vec2(t * 1.1, phase)) - 0.5,
        fbm(q * 1.1 + vec2(phase, t * 0.95)) - 0.5);
    vec2 dispPx = (vec2(sway * 15.0, abs(sway) * 3.0) * bend +
        flutter * 7.0 * bend * bend * gust) * amp;
    suv = uv - dispPx / uImg;
    // Leaves catching the light as they turn.
    lit = 1.0 + 0.07 * bend * amp * sin(t * 0.9 + phase + 0.6) * gust;
  }
  vec4 leaf = texture(uLeaves, suv);
  col = leaf.rgb * lit + col * (1.0 - leaf.a);
  fragColor = vec4(min(col, vec3(1.0)), 1.0);
}
