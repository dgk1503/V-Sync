// Liquid Glass navbar effect.
//
// Runs inside a BackdropFilter via ImageFilter.shader. CONTRACT (verified
// against Impeller's runtime_effect_filter_contents.cc):
//   * The engine OVERWRITES the first vec2 uniform (indices 0-1) with the
//     backdrop texture's pixel size, and renders the shader quad at that
//     size — so FlutterFragCoord() is in SCREEN pixel space.
//   * The backdrop sampler maps screen -> texture 1:1 via
//     uv = FlutterFragCoord() / uSize, EXCEPT on the GLES backend, where
//     the y-axis direction is reversed (gl_FragCoord is bottom-up). This
//     is a BACKEND property, not a platform one: the same Android device
//     can run Impeller/Vulkan (no flip) or fall back to Impeller/OpenGLES
//     (flip needed). The shader ships as raw GLSL and is compiled on
//     device per backend, so the official docs' #ifdef
//     IMPELLER_TARGET_OPENGLES is the correct, backend-aware fix — do NOT
//     hard-code the flip per platform (that shipped broken on Play:
//     Vulkan devices showed mirrored top-of-screen content in the glass).
//   * The capsule locates itself on screen via uCapsuleOrigin/uCapsuleSize
//     (physical px), which the SDF needs for the refraction band.
//
// Float uniforms (indices):
//   0-1: uSize         — engine-owned backdrop texture size (px). Do not set.
//   2-3: uCapsuleOrigin — capsule top-left in screen px
//   4-5: uCapsuleSize   — capsule size in px
//   6  : uRadius       — capsule corner radius in px
//   7  : uEdge         — refraction band width in px
//   8  : uBlur         — internal blur radius in px

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uCapsuleOrigin;
uniform vec2 uCapsuleSize;
uniform float uRadius;
uniform float uEdge;
uniform float uBlur;
uniform sampler2D uBackdrop;

out vec4 fragColor;

// Screen-space pixel coordinate -> backdrop texture UV.
vec2 sampleUv(vec2 coordPx) {
  vec2 uv = coordPx / uSize;
  // Reverse y axis on the GLES backend only (docs-mandated; see above).
  #ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
  #endif
  return clamp(uv, vec2(0.002), vec2(0.998));
}

float sdRoundedBox(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + r;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Cheap per-pixel hash, used only for sub-LSB dithering.
float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = sampleUv(fragCoord);

  // Capsule SDF in screen space.
  vec2 center = uCapsuleOrigin + uCapsuleSize * 0.5;
  vec2 halfSize = uCapsuleSize * 0.5 - 1.0;
  vec2 p = fragCoord - center;
  float d = sdRoundedBox(p, halfSize, uRadius);

  // Surface normal from the SDF gradient (central differences).
  vec2 grad = vec2(
    sdRoundedBox(p + vec2(1.0, 0.0), halfSize, uRadius) -
        sdRoundedBox(p - vec2(1.0, 0.0), halfSize, uRadius),
    sdRoundedBox(p + vec2(0.0, 1.0), halfSize, uRadius) -
        sdRoundedBox(p - vec2(0.0, 1.0), halfSize, uRadius)
  );
  vec2 normal = normalize(grad + vec2(0.0001));

  // Refraction: full strength at the rim, easing to zero uEdge px inwards.
  // A smoothstep (rather than a raw squared band) makes the image bend like
  // a lens instead of snapping on at the edge.
  float t = clamp(-d / uEdge, 0.0, 1.0);
  float bend = 1.0 - t;
  bend = bend * bend * (3.0 - 2.0 * bend);
  vec2 refracted = fragCoord - normal * (bend * uEdge * 0.85);

  // Real glass is optically CLEAR in the middle — text scrolling behind stays
  // crisp — and only the curved rim frosts. So: one clear tap, plus an
  // 8-tap RING for the frosted band. A ring, not a cross: four axis taps
  // leave a visible plus-shaped block pattern behind the glass, and that is
  // what read as "pixelated". R, G and B all bend by the same amount, so
  // content keeps its real colours.
  vec4 clear = texture(uBackdrop, sampleUv(refracted));
  vec4 sum = clear;
  for (int i = 0; i < 8; i++) {
    float a = float(i) * 0.7853981634; // 45 degrees
    vec2 o = vec2(cos(a), sin(a)) * uBlur;
    sum += texture(uBackdrop, sampleUv(refracted + o));
  }
  vec4 soft = sum / 9.0;

  // 1 in the capsule middle, 0 inside the refraction band.
  float interior = smoothstep(0.0, uEdge * 0.9, d);
  vec3 col = mix(soft.rgb, clear.rgb, interior);

  // Reflections. Three cheap layers, all neutral white, and together they are
  // what makes the capsule read as a solid slab of glass rather than a
  // blurred rectangle:
  //   * a broad rim (the curve catching the room),
  //   * a tight bright line right at the very edge (the polished bevel),
  //   * a sheen across the upper third plus a dark lower band (the slab's
  //     thickness — light lands on top, shadow collects underneath).
  float rim = 1.0 - smoothstep(0.0, 5.0, -d);
  float bevel = 1.0 - smoothstep(0.0, 1.5, -d);
  float key = clamp(dot(normal, normalize(vec2(-0.55, -0.78))), 0.0, 1.0);
  float fillLight = clamp(dot(normal, normalize(vec2(0.65, 0.72))), 0.0, 1.0);
  col += rim * (0.10 + 0.70 * key * key);
  col += bevel * 0.40 * key;
  col += rim * 0.16 * fillLight * fillLight * fillLight;

  // vy: 0 at the capsule's top edge, 1 at its bottom.
  float vy = (p.y + halfSize.y) / (2.0 * halfSize.y);
  float inside = smoothstep(0.0, 5.0, d);
  col += (1.0 - smoothstep(0.0, 0.38, vy)) * inside * 0.10;
  col *= 1.0 - smoothstep(0.72, 1.0, vy) * inside * 0.12;

  // A touch of saturation, then a sub-LSB dither: a smooth gradient across
  // ~15 px bands badly in 8-bit on a wide dark screen, and the dither turns
  // those rings back into a smooth sweep.
  float luma = dot(col, vec3(0.299, 0.587, 0.114));
  col = mix(vec3(luma), col, 1.04) * 1.02;
  col += (hash21(floor(fragCoord)) - 0.5) * (1.6 / 255.0);

  fragColor = vec4(col, clear.a);
}
