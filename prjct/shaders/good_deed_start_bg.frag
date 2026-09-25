#version 460 core

#include <flutter/runtime_effect.glsl>

// The Good Deed Tree start screen: the leafy clumps and flowers in the
// bottom corners sway in the wind. uSway: r = plant (moves), g = flower
// heads (nod further on their stems), b = freedom (0 on and beside the
// rocks, which hold still and stay in front). uUnder is the art with the
// plants painted out, so lawn shows where a leaf swings away.

uniform vec2 uSize;
uniform float uTime;
uniform sampler2D uBg;
uniform sampler2D uUnder;
uniform sampler2D uSway;

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

vec4 swayAt(vec2 uv) {
  if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(0.0);
  return texture(uSway, uv);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 uv = p / uSize;
  float t = uTime;
  vec4 here = texture(uBg, uv);
  vec4 sw = swayAt(uv);

  // Rooted below the frame: the higher up the clump, the more it bends.
  float bend = pow(clamp((1.0 - uv.y) / 0.21, 0.0, 1.0), 1.3);

  float gust = smoothstep(0.2, 0.9, noise(vec2(t * 0.2, 3.1)));
  float breeze = 0.35 + 0.65 * gust;

  // Wind rolling across, left to right.
  float wave = sin(t * 1.5 - uv.x * 6.0 + noise(uv * 4.0) * 2.0);

  // Each leaf flutters on its own.
  vec2 q = uv * vec2(14.0, 30.0);
  float fx = noise(q + vec2(t * 2.2, t * 0.6));
  float fy = noise(q + vec2(-t * 1.8, t * 1.5) + 17.0);

  vec2 d = vec2(wave * 5.0 + (fx - 0.5) * 3.0, (fy - 0.5) * 2.0 - abs(wave) * 1.0);

  // Flower heads nod further on their stems.
  d.x += sin(t * 2.3 + uv.x * 24.0 + uv.y * 9.0) * 3.5 * sw.g;

  // Authored in px of the 851px-wide art.
  d *= breeze * bend * sw.b * (uSize.x / 851.0);

  vec2 s = (p - d) / uSize;
  float m = swayAt(s).r;
  vec4 plant = texture(uBg, s) * m;
  plant.rgb *= 1.0 + (fx - 0.5) * 0.12 * breeze * bend;

  // Lawn behind the plants: the original where no plant was, the painted-out
  // art where one swung away.
  vec4 back = here * (1.0 - sw.r) + texture(uUnder, uv) * sw.r;

  // Rocks (no freedom, not plant) stay in front.
  float rock = (1.0 - sw.r) * (1.0 - smoothstep(0.0, 0.15, sw.b));
  vec4 front = here * rock;

  vec4 scene = plant + back * (1.0 - plant.a);
  fragColor = front + scene * (1.0 - front.a);
}
