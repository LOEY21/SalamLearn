#version 460 core

#include <flutter/runtime_effect.glsl>

// Five Pillars start screen: the painted courtyard, brought to life.
// uMask channels: r = which palm (sway phase), g = open sky (rays),
// b = marble floor (sun glints).
// uPalm: rg = offset from the palm's root (px / 800 + 0.5), b = how much
// the pixel bends (0 at the root, 1 at the frond tips).

uniform vec2 uSize;
uniform vec2 uImg;
uniform float uTime;
// Entrance push-in: magnification about uFocus (image uv).
uniform float uZoom;
uniform vec2 uFocus;
uniform sampler2D uBg;
uniform sampler2D uMask;
uniform sampler2D uPalm;

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
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(17.1, 9.2);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float t = uTime;

  // BoxFit.cover, aligned top-center.
  float s = max(uSize.x / uImg.x, uSize.y / uImg.y);
  vec2 d = uImg * s;
  vec2 uv = (p - vec2((uSize.x - d.x) * 0.5, 0.0)) / d;
  uv = uFocus + (uv - uFocus) / uZoom;
  float aspect = uImg.y / uImg.x;

  vec3 m = texture(uMask, uv).rgb;
  float sky = m.g;
  float floorM = m.b;

  // Palms: each bends about its own root like a pendulum with a slow wind
  // envelope, fronds flutter near the tips. Offsets are image pixels.
  vec3 pm = texture(uPalm, uv).rgb;
  float bend = pm.b;
  vec2 fromRoot = (pm.rg - 0.5) * 800.0;
  float phase = m.r * 23.0;
  float gust = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 0.31)) * (0.6 + 0.4 * sin(t * 0.17 + 1.3));
  float angle = gust * (0.030 * sin(t * 1.05 + phase) + 0.010 * sin(t * 2.2 + phase * 1.7));
  vec2 q = uv * vec2(1.0, aspect);
  vec2 flutter = vec2(
      fbm(q * 30.0 + vec2(t * 1.3, phase)) - 0.5,
      fbm(q * 30.0 + vec2(phase, t * 1.1)) - 0.5) * 5.0 * bend * bend;
  vec2 dispPx = -angle * bend * vec2(-fromRoot.y, fromRoot.x) + flutter * gust;
  vec2 suv = uv + dispPx / uImg;
  // Never pull pixels off a building: the sample must land on palm or sky.
  float okPalm = step(0.02, texture(uPalm, suv).b);
  float okSky = step(0.5, texture(uMask, suv).g);
  suv = mix(uv, suv, max(okPalm, okSky) * step(0.001, bend));
  vec3 col = texture(uBg, suv).rgb;

  // Fronds catching light as they turn.
  col *= 1.0 + bend * 0.06 * sin(t * 1.05 + phase + 0.6) * gust;

  // Sun just past the top-right corner: glow plus slowly turning rays.
  vec2 sun = vec2(0.95, -0.04);
  vec2 sv = (uv - sun) * vec2(1.0, aspect);
  float r = length(sv);
  float ang = atan(sv.y, sv.x);
  float rays = noise(vec2(ang * 16.0, t * 0.12)) * 0.65 +
      noise(vec2(ang * 37.0 - t * 0.07, 5.0)) * 0.35;
  rays = pow(rays, 2.2) * exp(-r * 1.1);
  float glow = exp(-r * r * 9.0);
  vec3 sunCol = vec3(1.0, 0.94, 0.78);
  float air = 0.35 + 0.65 * sky;
  col += sunCol * (rays * 0.32 * air + glow * 0.28);

  // Marble floor: a broad sheen that slides with the light, a shimmering
  // hotspot where the sun lands, and a few twinkling glints.
  if (floorM > 0.001) {
    float fy = (uv.y - 0.62) / 0.38;
    float band = 0.5 + 0.5 * sin((uv.x * 1.4 - uv.y * aspect * 0.9) * 7.0 + t * 0.45);
    float sheen = pow(band, 6.0) * 0.07;
    float ripple = fbm(vec2(uv.x * 18.0, uv.y * aspect * 30.0) + vec2(t * 0.25, -t * 0.18));
    vec2 hs = (uv - vec2(0.64, 0.74)) * vec2(2.6, aspect * 5.0);
    float hot = exp(-dot(hs, hs)) * (0.55 + 0.45 * ripple) * 0.2;
    vec2 cell = floor(uv * vec2(70.0, 70.0 * aspect));
    float h = hash(cell);
    vec2 inCell = fract(uv * vec2(70.0, 70.0 * aspect)) - 0.5;
    float twinkle = pow(max(0.0, sin(t * 2.2 + h * 40.0)), 24.0);
    float glint = step(0.93, h) * twinkle * exp(-dot(inCell, inCell) * 40.0) * 0.45;
    float nearSun = 0.5 + 0.5 * smoothstep(0.0, 1.0, uv.x);
    col += sunCol * (sheen + hot + glint * nearSun) * floorM * (1.0 - fy * 0.35);
  }

  fragColor = vec4(min(col, vec3(1.0)), 1.0);
}
