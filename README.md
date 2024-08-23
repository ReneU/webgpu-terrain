# WebGPU Terrain

Procedural terrain generation with Perlin noise using WebGPU.

## Heightmap generation

The grid is created initially on the CPU and then uploaded to the GPU. Here, the heightmap is generated using Perlin noise. For learning purposes, the Perlin noise is implemented in the shader and will be re-generated with every frame even though it is not necessary. When changing the x/y position of the camera, the heightmap is updated accordingly but the grid remains the same.

The terrain colors are interpolated based on the height of the terrain. There are five different colors for the terrain: water, sand, grass, rock, and snow. Unfortunately, this doesn't look very good for the watner/sand transition.

## Water

The water is implemented as an animated plane. The animation is done using a mix of multiple x and y sine waves.

## Lighting

The terrain is lit using a directional light. The Phong reflection model is used for the lighting calculations. The terrain is shaded based on the normal of the terrain at each vertex. The normals are calculated using the derivative of Perlin noise or animated water.

The lightning can be toggled on/off using the `Ctrl` key.

## Fog

The fog is implemented using a simple linear (smoothstep) fog model. The fog depth is the distance from the camera to the vertex and the color is interpolated between the fog color and the terrain color.

The fog can be toggled on/off using the `Option` key.