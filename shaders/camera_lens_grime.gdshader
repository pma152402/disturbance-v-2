shader_type canvas_item;
render_mode unshaded;
uniform float dirt : hint_range(0.0, 1.0) = 0.0;
uniform float central_clear : hint_range(0.0, 1.0) = 0.0;
uniform float wipe_progress = 0.0;
uniform bool wiping = false;
uniform float wash_progress = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
void fragment() {
 float large = noise(UV * vec2(6.0, 4.0) + 3.7);
 float small = noise(UV * vec2(26.0, 18.0));
 float drops = noise(UV * vec2(53.0, 10.0) + 8.0);
 float field = large * 0.64 + small * 0.28 + drops * 0.08;
 float patches = smoothstep(0.76 - dirt * 0.66, 0.87 - dirt * 0.65, field);
 float opacity = min(0.985, patches * (0.72 + dirt * 0.26) + dirt * 0.17);
 float oval = 1.0 - smoothstep(0.83, 1.17, length((UV - vec2(0.5,0.5)) / vec2(0.215,0.155)));
 float cleared = central_clear;
 if (wiping) cleared = max(cleared, smoothstep(0.0, 0.15, wipe_progress) * smoothstep(0.95 - wipe_progress * 0.9, 1.05 - wipe_progress * 0.9, UV.x));
 opacity *= 1.0 - oval * cleared * 0.98;
 opacity *= 1.0 - wash_progress;
 float bits = smoothstep(0.85, 0.94, noise(UV * 110.0));
 vec3 slime = mix(vec3(0.065,0.12,0.008), vec3(0.25,0.34,0.025), small);
 slime = mix(slime, vec3(0.48,0.19,0.022), bits * 0.8);
 COLOR = vec4(slime, opacity * step(0.001, dirt));
}
