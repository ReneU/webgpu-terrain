struct Uniforms {
  projectionMatrix : mat4x4f,
  modelViewMatrix : mat4x4f,
  fogColor : vec4f,
  lightDirection : vec4f,
  cameraPosition: vec4f,
  config : vec4f,
}
@binding(0) @group(0) var<uniform> uniforms : Uniforms;

struct VertexOut {
  @builtin(position) position : vec4f,
  @location(0) color : vec4f,
  @location(1) normal : vec3f,
  @location(2) fogDepth : f32
}

const WATER_COLOR = vec4(0.06, 0.37, 0.61, 1.0);
const SAND_COLOR = vec4(0.8, 0.52, 0.24, 1.0);
const GRASS_COLOR = vec4(0.13, 0.53, 0.0, 1.0);
const STONE_COLOR = vec4(0.65, 0.65, 0.65, 1.0);
const SNOW_COLOR = vec4(1.0, 1.0, 1.0, 1.0);

const WATER_THRESHOLD = 0.5;
const SAND_THRESHOLD = 0.51;
const GRASS_THRESHOLD = 0.55;
const STONE_THRESHOLD = 0.85;
const SNOW_THRESHOLD = 1.0;

const normalOffsetDelta = 0.032;

const terrainFractalLayers = 5;
const terrainAmplitudeFreq = 0.3;
const waveScale = 0.1;

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

fn randomGradient(p: vec2f) -> vec2f {
  let x = dot(p, vec2(123.4, 234.5));
  let y = dot(p, vec2(234.5, 345.6));
  var gradient = vec2(x, y);
  gradient = sin(gradient);
  gradient = gradient * 43758.5453;

  gradient = sin(gradient);
  return gradient;
}

fn quintic(p: vec2f) -> vec2f {
  return p * p * p * (10.0 + p * (-15.0 + p * 6.0));
}

// Perlin Noise
// https://github.com/SuboptimalEng/shader-tutorials/blob/main/05-perlin-noise/shader.frag
fn perlin(p: vec2f) -> f32 {
  // set up a grid of cells
  let gridId = floor(p);
  var gridUv = fract(p);

  // start by finding the coords of grid corners
  let bl = gridId + vec2f(0.0, 0.0);
  let br = gridId + vec2f(1.0, 0.0);
  let tl = gridId + vec2f(0.0, 1.0);
  let tr = gridId + vec2f(1.0, 1.0);

  // find random gradient for each grid corner
  let gradBl = randomGradient(bl);
  let gradBr = randomGradient(br);
  let gradTl = randomGradient(tl);
  let gradTr = randomGradient(tr);

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
  var fractal = 0.0;
  var amplitude = 1.0;
  var pt = p;
  for (var i = 0; i < terrainFractalLayers; i++) {
    fractal += perlin(pt) * amplitude;
    pt *= 2.0;
    amplitude *= terrainAmplitudeFreq;
  }
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

fn water(position: vec2f, t: f32) -> f32 {
  let x = position.x;
  let z = position.y;
  let scale = waveScale;
  let x_wave = (
    sin(x * 1.0 / scale + t * 1.0) +
    sin(x * 2.3 / scale + t * 1.5) +
    sin(x * 3.3 / scale + t * 0.4)
  ) / 3.0;
  let z_wave = (
    sin(z * 0.2 / scale + t * 1.8) +
    sin(z * 1.8 / scale + t * 1.8) +
    sin(z * 2.8 / scale + t * 0.8)
  ) / 3.0;
  return WATER_THRESHOLD + (x_wave + z_wave + 2.0) / 100.0;
}

fn waterNormal(position: vec2f, wave_value: f32, time: f32) -> vec3f {
  let position_offset_x = position.xy + vec2f(normalOffsetDelta, 0.0);
  let wave_offset_x = water(position_offset_x, time);
  let tangent_x = normalize(vec3f(position.xy, wave_value) - vec3f(position_offset_x, wave_offset_x));

  let position_offset_y = position.xy + vec2f(0.0, normalOffsetDelta);
  let wave_offset_y = water(position_offset_y, time);
  let tangent_y = normalize(vec3f(position.xy, wave_value) - vec3f(position_offset_y, wave_offset_y));

  return cross(tangent_x, tangent_y);
}

fn terrainColor(z: f32) -> vec4f {
  if(z < WATER_THRESHOLD) {
    return WATER_COLOR;
  } else if(z < SAND_THRESHOLD) {
    return mix(WATER_COLOR, SAND_COLOR, (z - WATER_THRESHOLD) / (SAND_THRESHOLD - WATER_THRESHOLD));
  } else if(z < GRASS_THRESHOLD) {
    return mix(SAND_COLOR, GRASS_COLOR, (z - SAND_THRESHOLD) / (GRASS_THRESHOLD - SAND_THRESHOLD));
  } else if(z < STONE_THRESHOLD) {
    return mix(GRASS_COLOR, STONE_COLOR, (z - GRASS_THRESHOLD) / (STONE_THRESHOLD - GRASS_THRESHOLD));
  } else {
    return mix(STONE_COLOR, SNOW_COLOR, (z - STONE_THRESHOLD) / (SNOW_THRESHOLD - STONE_THRESHOLD));
  }
}

@vertex
fn vertex_main(@location(0) position: vec4f) -> VertexOut {
  let time = uniforms.config.x;

  // Offset the position by the actual camera position to simulate the camera moving
  let offset_position = position.xz + uniforms.cameraPosition.xz;
  var terrain_value = terrainHeight(offset_position);
  var color = terrainColor(terrain_value);

  var normal = vec3f(0.0, 1.0, 0.0);
  if (terrain_value < WATER_THRESHOLD) {
    terrain_value = water(offset_position, time);
    normal = waterNormal(offset_position, terrain_value, time);
  } else {
    normal = terrainNormal(offset_position, terrain_value);
  }
  let terrain_position = vec4f(position.x, terrain_value, position.z, 1.0);

  var output = VertexOut();
  output.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * terrain_position;
  output.color = color;
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
  let color_light = light(fragData.normal, fragData.color, fragData.position.xyz);
  var color = select(fragData.color, color_light, lightsOn);
  if (!fogOn) {
    return color;
  } else {
    let fogAmount = smoothstep(2.0, 8.0, fragData.fogDepth);
    return mix(color, vec4f(0.8, 0.9, 1.0, 1.0), fogAmount);  
  }
}