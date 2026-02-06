struct Uniforms {
  projectionMatrix : mat4x4f,
  modelViewMatrix : mat4x4f,
  fogColor : vec4f,
  lightDirection : vec4f,
  cameraPosition: vec4f,
  config : vec4f,
}
@group(0) @binding(0)  var<uniform> uniforms : Uniforms;
@group(1) @binding(0) var grassSampler : sampler;
@group(1) @binding(1) var grassTex : texture_2d<f32>;
@group(1) @binding(2) var mudSampler : sampler;
@group(1) @binding(3) var mudTex : texture_2d<f32>;
@group(1) @binding(4) var rockSampler : sampler;
@group(1) @binding(5) var rockTex : texture_2d<f32>;

struct VertexOut {
  @builtin(position) position : vec4f,
  @location(1) normal : vec3f,
  @location(2) height : f32,
  @location(3) fogDepth : f32,
  @location(4) uv : vec2f,
}

const normalOffsetDelta = 0.032;

const terrainFractalLayers = 5;
const terrainAmplitudeFreq = 0.3;

const uLightDiffuse = vec4f(1.0, 1.0, 1.0, 1.0);

// Phong Light Model
// https://github.com/PacktPublishing/Real-Time-3D-Graphics-with-WebGL-2/blob/master/ch03/ch03_04_sphere-phong.html
fn light(normal: vec3f, materialDiffuse: vec4f, vertex: vec3f) -> vec4f {
  // Normalized light direction
  let L = normalize(uniforms.lightDirection.xyz);

  // Normalized normal
  let N = normalize(normal);

  let lambertTerm = dot(N, -L);
  if (lambertTerm > 0.0) {
    var Id = vec4f(uLightDiffuse * materialDiffuse * lambertTerm);
    return vec4f(Id.xyz, 1.0);
  } else {
    return vec4f(0.0, 0.0, 0.0, 1.0);
  }
}

fn randomGradient(p: vec2f, seed: f32) -> vec2f {
  let x = dot(p, vec2(123.4, 234.5));
  let y = dot(p, vec2(234.5, 345.6));
  var gradient = vec2(x, y);
  gradient = sin(gradient);
  gradient = gradient * 43758.5453 + seed;

  gradient = sin(gradient);
  return gradient;
}

fn quintic(p: vec2f) -> vec2f {
  return p * p * p * (10.0 + p * (-15.0 + p * 6.0));
}

// Perlin Noise
// https://github.com/SuboptimalEng/shader-tutorials/blob/main/05-perlin-noise/shader.frag
fn perlin(p: vec2f, seed: f32) -> f32 {
  // set up a grid of cells
  let gridId = floor(p);
  var gridUv = fract(p);

  // start by finding the coords of grid corners
  let bl = gridId + vec2f(0.0, 0.0);
  let br = gridId + vec2f(1.0, 0.0);
  let tl = gridId + vec2f(0.0, 1.0);
  let tr = gridId + vec2f(1.0, 1.0);

  // find random gradient for each grid corner
  let gradBl = randomGradient(bl, seed);
  let gradBr = randomGradient(br, seed);
  let gradTl = randomGradient(tl, seed);
  let gradTr = randomGradient(tr, seed);

  // find distance from current pixel to each grid corner
  let distFromPixelToBl = gridUv - vec2f(0.0, 0.0);
  let distFromPixelToBr = gridUv - vec2f(1.0, 0.0);
  let distFromPixelToTl = gridUv - vec2f(0.0, 1.0);
  let distFromPixelToTr = gridUv - vec2f(1.0, 1.0);

  // calculate the dot products of gradients + distances
  let dotBl = dot(gradBl, distFromPixelToBl);
  let dotBr = dot(gradBr, distFromPixelToBr);
  let dotTl = dot(gradTl, distFromPixelToTl);
  let dotTr = dot(gradTr, distFromPixelToTr);

  // smooth out gridUvs
  gridUv = quintic(gridUv);

  // perform linear interpolation between 4 dot products
  let b = mix(dotBl, dotBr, gridUv.x);
  let t = mix(dotTl, dotTr, gridUv.x);
  return mix(b, t, gridUv.y) / 2.0 + 0.5;
}

// Fractal Perlin Noise
fn terrainHeight(p: vec2f) -> f32 {
  let animationState = uniforms.config.w;
  var fractal = 0.0;
  fractal += perlin(p / 6, animationState) * 2.50;
  fractal += perlin(p,     animationState) * 0.80;
  fractal += perlin(p * 2, animationState) * 0.20;
  fractal += perlin(p * 4, animationState) * 0.10;
  fractal += perlin(p * 8, animationState) * 0.04;
  return fractal;
}

// Generate normal from perlin noise using derivatives
// https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/perlin-noise-part-2/perlin-noise-computing-derivatives.html
fn terrainNormal(position: vec2f, noise_value: f32) -> vec3f {
  // point a bit to the right of the original value
  let position_offset_x = position.xy + vec2f(normalOffsetDelta, 0.0);
  // what is its noise value
  let noise_offset_x = terrainHeight(position_offset_x);
  // a vector from the point to the other one, using the noise result
  // as the third dimension
  let tangent_x = normalize(vec3f(position.xy, noise_value) - vec3f(position_offset_x, noise_offset_x));

  // same for Y
  let position_offset_y = position.xy + vec2f(0.0, normalOffsetDelta);
  let noise_offset_y = terrainHeight(position_offset_y);
  let tangent_y = normalize(vec3f(position.xy, noise_value) - vec3f(position_offset_y, noise_offset_y));

  // cross product of the two tangents of the point will create
  // the normal vector at that point
  return cross(tangent_x, tangent_y);
}

@vertex
fn vertex_main(@location(0) position: vec4f) -> VertexOut {
  let time = uniforms.config.x;

  // Offset the position by the actual camera position to simulate the camera moving
  let offset_position = position.xz + uniforms.cameraPosition.xz;
  var terrain_value = terrainHeight(offset_position);

  var normal = vec3f(0.0, 1.0, 0.0);
  normal = terrainNormal(offset_position, terrain_value);
  let terrain_position = vec4f(position.x, terrain_value, position.z, 1.0);

  var output = VertexOut();
  output.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * terrain_position;
  output.height = terrain_value;
  output.uv = offset_position;
  output.normal = normal;
  // Fog depth is the distance from the camera to the vertex
  // https://webglfundamentals.org/webgl/lessons/webgl-fog.html
  output.fogDepth = -(uniforms.modelViewMatrix * terrain_position).z;
  return output;
}

@fragment
fn fragment_main(fragData: VertexOut) -> @location(0) vec4f {
  let fogOn = uniforms.config.y == 1.0;
  let lightsOn = uniforms.config.z == 1.0;

  let steepness = 1.0 - abs(dot(fragData.normal, vec3f(0.0, 1.0, 0.0)));
  let uv = abs(fragData.uv % 1.0);

  // Use steepness to mix between grass and mud textures
  var color = mix(
    textureSample(mudTex, mudSampler, uv),
    textureSample(grassTex, grassSampler, uv),
    smoothstep(0.3, 1.0, steepness)
  );
  // Use height to mix in rock texture on the peaks
  color = mix(
    color,
    textureSample(rockTex, rockSampler, uv),
    smoothstep(1.7, 2.3, fragData.height)
  );
  // Apply lighting if enabled
  color = select(color, light(fragData.normal, color, fragData.position.xyz), lightsOn);
  if (!fogOn) {
    return color;
  } else {
    let fogAmount = smoothstep(2.0, 8.0, fragData.fogDepth);
    return mix(color, vec4f(0.8, 0.9, 1.0, 1.0), fogAmount);  
  }
}