#version 460 core

#include <flutter/runtime_effect.glsl>

// Sirah Stories start screen: the painted square, brought to life.
// uClean: the backdrop with the drifting clouds and all foliage painted out.
// uPalms: the foliage alone (premultiplied), laid back over it as it sways.
// uField: rg = offset from the plant's root (px / 512 + 0.5), b = how far
//   the pixel bends (0 at the root, rising to the frond tips).
// uAux: r = the plant's sway rate (Hz), g = open sky, b = sway phase.
// uClouds: the four open-sky clouds cut from the backdrop (top 270 px).
// uLamp: the hanging lantern by the boy, swung on its chain and lit.
// uMode 1 outputs only the open-sky coverage, as a mask for the birds.

uniform vec2 uSize;
uniform float uTime;
uniform float uGust;
uniform float uMode;
uniform sampler2D uClean;
uniform sampler2D uPalms;
uniform sampler2D uField;
uniform sampler2D uAux;
uniform sampler2D uClouds;
uniform sampler2D uLamp;

out vec4 fragColor;

const vec2 kImg = vec2(1870.0, 841.0);
const vec2 kCloudImg = vec2(1870.0, 270.0);
// Lantern: where uLamp sits in the image, the hook it hangs from, the flame.
const vec4 kLamp = vec4(112.0, 284.0, 56.0, 136.0);
const vec2 kPivot = vec2(141.0, 290.0);
const vec2 kFlame = vec2(142.0, 382.0);
const vec3 kWarm = vec3(1.0, 0.7, 0.36);

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

// How far the foliage at p has moved, in image px. Each plant rocks about its
// root on its own rate and phase, leans further downwind as a gust builds,
// and its fronds rustle, most at the tips.
vec2 sway(vec2 p, vec3 aux) {
  vec3 f = texture(uField, p / kImg).rgb;
  float bend = f.b;
  if (bend < 0.002) return vec2(0.0);
  vec2 off = (f.rg - 0.5) * 512.0;
  float w = 6.2832 * aux.r;
  float ph = aux.b * 6.2832;
  float t = uTime;
  float rock = sin(w * t + ph) + 0.35 * sin(w * 2.13 * t + ph * 1.7);
  float ang = 0.05 * (0.55 * uGust + (0.25 + 0.5 * uGust) * 0.6 * rock);
  vec2 d = ang * bend * vec2(-off.y, off.x);
  vec2 q = p * 0.045;
  d += vec2(
      noise(q + vec2(t * 1.7, ph * 9.0)) - 0.5,
      noise(q + vec2(ph * 7.0, t * 1.4)) - 0.5) * 2.6 * bend * (0.4 + uGust);
  return d;
}

// One cloud drifting downwind and wrapping round. rect is where it sits in
// uClouds; its outline billows slowly and the thin edges come and go.
vec4 cloud(vec2 p, vec4 rect, float speed, float seed) {
  float period = kImg.x + rect.z + 160.0;
  float x0 = mod(rect.x + speed * uTime + rect.z + 80.0, period) - rect.z - 80.0;
  vec2 local = p - vec2(x0, rect.y + 3.0 * sin(uTime * 0.05 + seed));
  if (local.x < -10.0 || local.y < -10.0 ||
      local.x > rect.z + 10.0 || local.y > rect.w + 10.0) {
    return vec4(0.0);
  }
  float stretch = 1.0 + 0.035 * sin(uTime * 0.07 + seed * 3.0);
  local.x = (local.x - rect.z * 0.5) / stretch + rect.z * 0.5;
  vec2 n = vec2(
      noise(local * 0.03 + vec2(uTime * 0.08, seed)),
      noise(local * 0.03 + vec2(seed, uTime * 0.07))) - 0.5;
  local += n * 7.0;
  local = clamp(local, vec2(0.0), rect.zw);
  vec4 c = texture(uClouds, (rect.xy + local) / kCloudImg);
  float e = noise(local * 0.06 + vec2(uTime * 0.05, seed * 3.0));
  float thin = 0.3 * e;
  float a = clamp((c.a - thin) / (1.0 - thin), 0.0, 1.0);
  return c * (a / max(c.a, 0.001));
}

mat2 rot(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, s, -s, c);
}

// The lantern is a pendulum: pushed downwind by the gust and swinging about
// that lean at the rate its chain length gives, the swing slowly growing and
// dying away as the wind nudges it. Negative swings the foot to the right.
float lampAngle() {
  float t = uTime;
  float swing = (0.05 + 0.07 * uGust) * (0.75 + 0.25 * sin(t * 0.37)) *
      sin(6.2832 / 1.35 * t);
  return -(0.035 * uGust + swing);
}

vec3 over(vec3 col, vec4 c, float sky) {
  return col * (1.0 - c.a * sky) + c.rgb * sky;
}

void main() {
  vec2 p = FlutterFragCoord().xy / uSize * kImg;
  vec2 uv = p / kImg;
  vec3 aux = texture(uAux, uv).rgb;
  vec4 leaf = texture(uPalms, (p - sway(p, aux)) / kImg);

  if (uMode > 0.5) {
    float a = aux.g * (1.0 - leaf.a);
    fragColor = vec4(a);
    return;
  }

  vec3 col = texture(uClean, uv).rgb;
  float sky = aux.g;
  if (p.y < kCloudImg.y && sky > 0.0) {
    col = over(col, cloud(p, vec4(796.0, 161.0, 203.0, 77.0), 4.5, 2.1), sky);
    col = over(col, cloud(p, vec4(1085.0, 109.0, 179.0, 65.0), 11.0, 5.3), sky);
    col = over(col, cloud(p, vec4(293.0, 67.0, 313.0, 113.0), 8.0, 0.7), sky);
    col = over(col, cloud(p, vec4(1355.0, 59.0, 308.0, 114.0), 6.5, 3.9), sky);
  }
  col = col * (1.0 - leaf.a) + leaf.rgb;

  // The lantern's flame, flickering, and the light it throws: it scales with
  // the surface it lands on, so the wall and awning warm up rather than
  // wash out, and it follows the lantern as it swings.
  float t = uTime;
  float flick = 0.78 + 0.14 * noise(vec2(t * 7.0, 1.3)) +
      0.08 * noise(vec2(t * 19.0, 4.1));
  float ang = lampAngle();
  vec2 flame = kPivot + rot(ang) * (kFlame - kPivot);
  vec2 fd = p - flame;
  float r2 = dot(fd, fd);
  float thrown = exp(-r2 / 9800.0) * 0.32 + exp(-r2 / 51200.0) * 0.1;
  col += col * kWarm * thrown * flick;

  vec2 q = kPivot + rot(-ang) * (p - kPivot);
  vec2 lq = q - kLamp.xy;
  if (lq.x >= 0.0 && lq.y >= 0.0 && lq.x <= kLamp.z && lq.y <= kLamp.w) {
    vec4 lamp = texture(uLamp, lq / kLamp.zw);
    // The glass panes glow from within, brightest nearest the flame.
    vec3 base = lamp.rgb / max(lamp.a, 0.001);
    vec2 g = (q - kFlame) * vec2(1.0, 0.7);
    float glass = smoothstep(0.45, 0.75, dot(base, vec3(0.3, 0.59, 0.11))) *
        exp(-dot(g, g) / 392.0);
    lamp.rgb += lamp.a * kWarm * glass * flick * 0.6;
    // The flame itself, stretching and shrinking as it flickers.
    float lick = 0.85 + 0.3 * noise(vec2(t * 13.0, 7.7));
    vec2 fc = (q - kFlame - vec2(0.4 * sin(t * 9.0), 1.0)) /
        vec2(3.0, 6.0 * lick);
    float core = exp(-dot(fc, fc) * 1.5);
    lamp.rgb += lamp.a * vec3(1.0, 0.9, 0.62) * core * flick;
    col = col * (1.0 - lamp.a) + lamp.rgb;
  }

  // A soft bloom round the glass.
  col += kWarm * (exp(-r2 / 968.0) * 0.26 + exp(-r2 / 4608.0) * 0.07) * flick;
  fragColor = vec4(min(col, vec3(1.0)), 1.0);
}
