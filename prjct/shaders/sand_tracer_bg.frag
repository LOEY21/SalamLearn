#version 460 core

#include <flutter/runtime_effect.glsl>

// Magic Sand Tracer's courtyard, brought to life (start and game screens).
// Layers come from dumps/tracing_layers/gen_bg_layers.py.
// uClean: the backdrop with the drifting clouds and all foliage painted out.
// uPalms: the foliage alone (premultiplied), laid back over it as it sways.
// uField: rg = offset from the plant's root (px / 1024 + 0.5), b = how far
//   the pixel bends (0 at the root, rising to the frond tips).
// uAux: r = the plant's sway rate (Hz), g = open sky, b = sway phase.
// uClouds: the drifting clouds cut from the sky (top 700 px).

uniform vec2 uSize;
uniform float uTime;
uniform float uGust;
uniform sampler2D uClean;
uniform sampler2D uPalms;
uniform sampler2D uField;
uniform sampler2D uAux;
uniform sampler2D uClouds;

out vec4 fragColor;

const vec2 kImg = vec2(853.0, 1844.0);
const vec2 kCloudImg = vec2(853.0, 700.0);

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

// How far the foliage at p has moved, in image px. Each palm rocks about its
// root on its own slow rate and phase, leaning further as a gust builds, the
// tips travelling most (bushes and ferns have no bend, so they hold still). Leaves flutter in broad, slow patches so
// whole fronds move together instead of the art wobbling pixel by pixel.
vec2 sway(vec2 p, vec3 aux) {
  vec3 f = texture(uField, p / kImg).rgb;
  float bend = f.b;
  if (bend < 0.002) return vec2(0.0);
  vec2 off = (f.rg - 0.5) * 1024.0;
  float w = 6.2832 * aux.r;
  float ph = aux.b * 6.2832;
  float t = uTime;
  float rock = sin(w * t + ph) + 0.3 * sin(w * 1.73 * t + ph * 1.7) +
      0.15 * sin(w * 3.1 * t + ph * 2.3);
  float ang = 0.09 * (0.3 * uGust + (0.3 + 0.45 * uGust) * 0.6 * rock);
  vec2 d = ang * bend * vec2(-off.y, off.x);
  vec2 q = p * 0.012;
  d += vec2(
      noise(q + vec2(t * 0.5, ph * 9.0)) - 0.5,
      noise(q + vec2(ph * 7.0, t * 0.45)) - 0.5) *
      1.4 * bend * bend * (0.4 + uGust);
  return d;
}

// One cloud, held still where it was painted (kCloudT is its moment in the
// old drift, 0 = its own spot). rect is where it sits in uClouds; its box's
// ends fade so a cloud cut by a palm or the frame has no hard edge.
const float kCloudT = 0.0;

vec4 cloud(vec2 p, vec4 rect, float speed, float seed) {
  float period = kImg.x + rect.z + 160.0;
  float x0 = mod(rect.x + speed * kCloudT + rect.z + 80.0, period) - rect.z - 80.0;
  vec2 local = p - vec2(x0, rect.y + 3.0 * sin(kCloudT * 0.05 + seed));
  if (local.x < -10.0 || local.y < -10.0 ||
      local.x > rect.z + 10.0 || local.y > rect.w + 10.0) {
    return vec4(0.0);
  }
  float ends = smoothstep(0.0, 30.0, local.x) *
      smoothstep(0.0, 30.0, rect.z - local.x) *
      smoothstep(0.0, 10.0, local.y) * smoothstep(0.0, 10.0, rect.w - local.y);
  float stretch = 1.0 + 0.035 * sin(kCloudT * 0.07 + seed * 3.0);
  local.x = (local.x - rect.z * 0.5) / stretch + rect.z * 0.5;
  vec2 n = vec2(
      noise(local * 0.03 + vec2(kCloudT * 0.08, seed)),
      noise(local * 0.03 + vec2(seed, kCloudT * 0.07))) - 0.5;
  local += n * 5.0;
  local = clamp(local, vec2(0.0), rect.zw);
  vec4 c = texture(uClouds, (rect.xy + local) / kCloudImg);
  float e = noise(local * 0.06 + vec2(kCloudT * 0.05, seed * 3.0));
  float thin = 0.3 * e;
  float a = clamp((c.a - thin) / (1.0 - thin), 0.0, 1.0) * ends;
  return c * (a / max(c.a, 0.001));
}

vec3 over(vec3 col, vec4 c, float sky) {
  return col * (1.0 - c.a * sky) + c.rgb * sky;
}

void main() {
  vec2 p = FlutterFragCoord().xy / uSize * kImg;
  vec2 uv = p / kImg;
  vec3 aux = texture(uAux, uv).rgb;
  vec4 leaf = texture(uPalms, (p - sway(p, aux)) / kImg);

  vec3 col = texture(uClean, uv).rgb;
  float sky = aux.g;
  if (p.y < kCloudImg.y && sky > 0.0) {
    col = over(col, cloud(p, vec4(0.0, 104.0, 378.0, 214.0), 5.9, 8.8), sky);
    col = over(col, cloud(p, vec4(480.0, 292.0, 373.0, 158.0), 4.4, 7.7), sky);
    col = over(col, cloud(p, vec4(0.0, 318.0, 358.0, 142.0), 4.5, 1.3), sky);
    col = over(col, cloud(p, vec4(505.0, 76.0, 220.0, 90.0), 6.3, 2.8), sky);
    col = over(col, cloud(p, vec4(403.0, 446.0, 192.0, 64.0), 4.4, 1.6), sky);
    col = over(col, cloud(p, vec4(466.0, 236.0, 164.0, 56.0), 5.7, 5.8), sky);
    col = over(col, cloud(p, vec4(425.0, 12.0, 165.0, 50.0), 7.1, 4.9), sky);
    col = over(col, cloud(p, vec4(152.0, 470.0, 80.0, 42.0), 3.6, 0.5), sky);
  }
  col = col * (1.0 - leaf.a) + leaf.rgb;
  fragColor = vec4(col, 1.0);
}
