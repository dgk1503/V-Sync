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

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;

  // Straight-through, screen-aligned sampling: the glass is see-through by
  // default; only the edge band below bends the image.
  vec2 uv = sampleUv(fragCoord);

  // Capsule SDF in screen space.
  vec2 center = uCapsuleOrigin + uCapsuleSize * 0.5;
  vec2 halfSize = uCapsuleSize * 0.5 - 1.0;
  vec2 p = fragCoord - center;

  float d = sdRoundedBox(p, halfSize, uRadius);

  // Surface normal from the SDF gradient (central differences).
  float e = 1.0;
  vec2 grad = vec2(
    sdRoundedBox(p + vec2(e, 0.0), halfSize, uRadius) -
        sdRoundedBox(p - vec2(e, 0.0), halfSize, uRadius),
    sdRoundedBox(p + vec2(0.0, e), halfSize, uRadius) -
        sdRoundedBox(p - vec2(0.0, e), halfSize, uRadius)
  );
  vec2 normal = normalize(grad + vec2(0.0001));

  // Refraction band: 1 right at the edge, fading inwards across uEdge px.
  float band = clamp(-d / uEdge, 0.0, 1.0);
  float edge = (1.0 - band) * (1.0 - band);

  // Glass interior: keep it clear, just soften very slightly with a
  // 5-tap cross blur.
  // True-color reflection: R, G and B are sampled from the SAME position
  // (no chromatic aberration) so underlying content keeps its real colors —
  // white text reflects as white, not pink/green.
  vec2 refracted = fragCoord - normal * (edge * uEdge * 0.42);
  vec4 col = texture(uBackdrop, sampleUv(refracted)) * 0.36 +
             (texture(uBackdrop, sampleUv(refracted + vec2(uBlur, 0.0))) +
              texture(uBackdrop, sampleUv(refracted - vec2(uBlur, 0.0))) +
              texture(uBackdrop, sampleUv(refracted + vec2(0.0, uBlur))) +
              texture(uBackdrop, sampleUv(refracted - vec2(0.0, uBlur)))) * 0.16;

  // Specular rim, strongest where the normal faces the top-left light.
  float rim = smoothstep(0.0, 2.5, -d) * (1.0 - smoothstep(2.5, 6.0, -d));
  float lit = clamp(dot(normal, normalize(vec2(-0.7, -0.7))), 0.0, 1.0);
  col.rgb += rim * mix(0.03, 0.42, lit);

  // Glass liveliness: a touch of saturation and brightness lift.
  float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
  col.rgb = mix(vec3(luma), col.rgb, 1.04) * 1.02;

  fragColor = col;
}
