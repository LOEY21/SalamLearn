#version 460 core

#include <flutter/runtime_effect.glsl>

// The Good Deed Tree: only the leaves move. uMask marks the leaves; trunk,
// branches, blossoms and fruit are drawn untouched on top. Gusts roll across
// the crown as a travelling wave, each leaf cluster flutters on its own, and
// leaves catch the light as they turn. Outer leaves move freely; leaves
// touching anything that holds still settle to it, so no gaps open up.
// Fruit, where the tree has any, swings gently from its stem: uFruit holds
// each fruit pixel's offset to its stem (rg) and how much fruit it is (b),
// and uUnder is the tree with the fruit painted out, so the leaves behind
// show as a fruit swings.

uniform vec2 uSize;
uniform float uTime;
uniform float uFruitOn;
uniform sampler2D uTree;
uniform sampler2D uMask;
uniform sampler2D uUnder;
uniform sampler2D uFruit;

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

float maskAt(vec2 uv) {
  if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
  return texture(uMask, uv).r;
}

vec4 treeAt(vec2 uv) {
  if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(0.0);
  return texture(uTree, uv);
}

vec4 underAt(vec2 uv) {
  if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(0.0);
  return texture(uUnder, uv);
}

// How much of this spot is fruit (0 outside every fruit's swing zone).
float fruitAt(vec2 uv) {
  if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
  return clamp(texture(uFruit, uv).b * 2.0 - 1.0, 0.0, 1.0);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 uv = p / uSize;
  float t = uTime;
  float k = uSize.x / 292.0;

  // Around this spot: open sky lets leaves swing out further, anything
  // still (branch, blossom, fruit) pins them.
  float sky = 0.0;
  float still = 0.0;
  for (int i = 0; i < 8; i++) {
    float an = float(i) * 0.785398;
    vec2 o = uv + vec2(cos(an), sin(an)) * (6.0 * k) / uSize;
    float m = maskAt(o);
    float a = treeAt(o).a;
    sky += 1.0 - a;
    still += a * (1.0 - m);
  }
  sky /= 8.0;
  still = clamp(still / 8.0 * 3.0, 0.0, 1.0);
  float free = (1.0 + sky * 0.8) * (1.0 - still) * mix(1.0, 0.6, uv.y);

  // Gust strength rises and falls slowly.
  float gust = smoothstep(0.2, 0.9, noise(vec2(t * 0.18, 7.3)));
  float breeze = 0.35 + 0.65 * gust;

  // A wave of wind rolling across the crown, left to right.
  float wave = sin(t * 1.6 - uv.x * 4.0 - uv.y * 1.5 + noise(uv * 3.0) * 2.0);
  vec2 d = vec2(wave * 1.8, wave * 0.5 - 0.3) * breeze;

  // Each cluster flutters at its own pace.
  vec2 q = uv * vec2(16.0, 20.0);
  float fx = noise(q + vec2(t * 2.6, t * 0.7));
  float fy = noise(q + vec2(-t * 2.1, t * 1.9) + 31.0);
  d += (vec2(fx, fy) - 0.5) * vec2(2.2, 1.6) * (0.5 + breeze);

  d *= free * k;

  // Moving leaves.
  vec2 s = (p - d) / uSize;
  vec4 leaves = underAt(s) * maskAt(s);
  float turn = (fx - 0.5) * 0.22 * breeze + (wave * 0.5 + 0.5) * 0.05;
  leaves.rgb *= 1.0 + turn * (1.0 - still);

  // Fruit swinging from its stem, each at its own pace.
  vec4 fruit = vec4(0.0);
  if (uFruitOn > 0.5) {
    vec4 fi = texture(uFruit, uv);
    if (fi.b > 0.25) {
      vec2 pivot = (uv + (fi.rg - 0.5) / 2.5) * uSize;
      // Smooth in the pivot, so rounding in the map can't split a fruit.
      float ph = dot(pivot / k, vec2(0.05, 0.03));
      float rate = 1.3 + 0.25 * (1.0 + sin(ph * 1.7));
      float ang = (sin(t * rate + ph) * 0.7 + sin(t * 2.3 + ph * 0.5) * 0.3) *
                  0.07 * (0.5 + 0.5 * breeze);
      vec2 r = p - pivot;
      float c = cos(ang);
      float sn = sin(ang);
      vec2 src = (pivot + vec2(c * r.x + sn * r.y, -sn * r.x + c * r.y)) / uSize;
      fruit = treeAt(src) * fruitAt(src);
    }
  }

  // Everything else, unmoved, in front.
  vec4 here = treeAt(uv);
  vec4 fixedPart = here * (1.0 - maskAt(uv));
  vec4 behind = fruit + leaves * (1.0 - fruit.a);
  fragColor = fixedPart + behind * (1.0 - fixedPart.a);

  // Root flare shaded where it sinks into the soil.
  fragColor.rgb *= 1.0 - 0.3 * smoothstep(0.8, 0.94, uv.y);
}
