#include <flutter/runtime_effect.glsl>

// Liquid Glass edge refraction.
//
// Frosted blur alone is not what makes iOS 26's glass read as glass. Real glass is
// a *lens*: it bends light passing through it, so the content behind appears
// displaced — and stretched or inverted — most strongly near the rim where the
// material is thickest. It also disperses, splitting that light very slightly into
// its colour components, which is the faint pink/green fringing visible along the
// edge of Apple's own tab bars.
//
// A `BackdropFilter` can only blur; it cannot displace. This shader supplies the
// displacement, and is composed *over* a blur (see `GlassRefraction`) so the two
// effects stack in one filter pass.
//
// Uniform order is dictated by `ImageFilter.shader`: the first uniform must be a
// vec2 that the engine fills with the bound texture's size, and the first
// sampler2D is filled with the filter input (here, the already-blurred backdrop).
// Everything between is ours.

uniform vec2 uSize;

// Corner radius of the surface, in pixels. Drives the signed-distance field, so
// the lensing follows a capsule's rounded ends rather than a plain rectangle.
uniform float uRadius;

// Maximum inward displacement at the rim, in pixels.
uniform float uRefraction;

// Fraction by which the red and blue channels are displaced more/less than green.
// Small values only — this should read as a hint of colour at the edge, not as a
// broken image.
uniform float uDispersion;

// How far in from the edge the lensing reaches, in pixels. Beyond this the
// surface is optically flat and the backdrop passes through undisplaced.
uniform float uEdgeWidth;

uniform sampler2D uTexture;

out vec4 fragColor;

/// Signed distance from `p` to a rounded rectangle of half-size `b` and corner
/// radius `r`, centred on the origin. Negative inside, zero on the edge.
float sdRoundRect(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

/// Outward-facing normal of that field, by central difference.
///
/// A radial `normalize(p)` would be cheaper but is wrong for a capsule: it points
/// diagonally along the long top and bottom edges, so those would refract sideways
/// instead of vertically. Four extra distance evaluations buy a correct normal
/// everywhere on the shape.
vec2 sdNormal(vec2 p, vec2 b, float r) {
  const float e = 1.0;
  float dx = sdRoundRect(p + vec2(e, 0.0), b, r) - sdRoundRect(p - vec2(e, 0.0), b, r);
  float dy = sdRoundRect(p + vec2(0.0, e), b, r) - sdRoundRect(p - vec2(0.0, e), b, r);
  return normalize(vec2(dx, dy) + vec2(1e-6));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 halfSize = uSize * 0.5;
  vec2 p = frag - halfSize;

  float dist = sdRoundRect(p, halfSize, uRadius);

  // 0 at the optical centre, 1 hard against the rim.
  float t = 1.0 - clamp(-dist / max(uEdgeWidth, 1.0), 0.0, 1.0);

  // Squared so the bend concentrates in the last few pixels, the way thickness
  // ramps in a real bevel. A linear falloff reads as a smear across the whole
  // surface instead of an edge.
  float lens = t * t;

  vec2 normal = sdNormal(p, halfSize, uRadius);

  // Sample *inward* along the normal: content near the edge is pulled toward the
  // centre, which is what produces the stretched, partly inverted band that makes
  // the surface read as a lens rather than as frosted film.
  vec2 offset = normal * lens * uRefraction;

  vec2 uvR = (frag - offset * (1.0 + uDispersion)) / uSize;
  vec2 uvG = (frag - offset) / uSize;
  vec2 uvB = (frag - offset * (1.0 - uDispersion)) / uSize;

  // Impeller's OpenGLES backend hands us a y-flipped texture. iOS runs Metal, so
  // this is inert there, but leaving it out would render upside-down on a GLES
  // device.
#ifdef IMPELLER_TARGET_OPENGLES
  uvR.y = 1.0 - uvR.y;
  uvG.y = 1.0 - uvG.y;
  uvB.y = 1.0 - uvB.y;
#endif

  // Clamp rather than letting the sampler wrap: an unclamped read near the rim
  // pulls in pixels from the opposite side of the surface as a bright seam.
  uvR = clamp(uvR, vec2(0.0), vec2(1.0));
  uvG = clamp(uvG, vec2(0.0), vec2(1.0));
  uvB = clamp(uvB, vec2(0.0), vec2(1.0));

  vec4 centre = texture(uTexture, uvG);

  fragColor = vec4(
    texture(uTexture, uvR).r,
    centre.g,
    texture(uTexture, uvB).b,
    centre.a
  );
}
