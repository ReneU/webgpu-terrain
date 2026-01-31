import { mat4, vec2, vec4 } from 'wgpu-matrix';
import shaderString from './shader.wgsl?raw';
import { Camera } from './Camera';
import { Uniforms } from './Uniforms';
import { Controls } from './Controls';

// Constants
const CONTROLS_SPEED = 0.002;
const WATER_SPEED = 800;
const STEPS = 800;
const MAX_BOUNDS = 8.0;
const STEP_SIZE = 1 / (STEPS - 1) * (MAX_BOUNDS * 2);
const FOG_COLOR = vec4.fromValues(0.8, 0.9, 1.0, 1.0);
const START_POSITION = vec4.fromValues(0.0, 3.0, 0.0);
const LIGHT_DIRECTION = vec4.fromValues(-0.25, -0.25, -0.25, 0.0);

// Variables
let previousTime = performance.now();

const start = async () => {

  if (!navigator.gpu) {
    throw Error('WebGPU not supported.');
  }

  const adapter = await navigator.gpu.requestAdapter();
  if (!adapter) {
    throw Error('Couldn\'t request WebGPU adapter.');
  }

  const device = await adapter.requestDevice();

  const canvas = document.querySelector('#gpuCanvas') as HTMLCanvasElement;
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;

  const context = canvas.getContext('webgpu')!;

  const vertices = [];
  for (let x = -MAX_BOUNDS; x <= MAX_BOUNDS; x = x + STEP_SIZE) {
    for (let y = -MAX_BOUNDS; y <= MAX_BOUNDS; y = y + STEP_SIZE) {
      vertices.push(x, 0, y);
    }
  }

  const verticesf32 = new Float32Array(vertices);

  const indices = []
  for (let i = 0; i <= STEPS - 2; i++) {
    for (let j = 0; j <= STEPS - 2; j++) {
      const bl = (i * STEPS) + j;
      const tl = (i * STEPS) + j + 1;
      const tr = (i + 1) * STEPS + j + 1
      const br = (i + 1) * STEPS + j
      indices.push(bl, tl, br);
      indices.push(tl, br, tr);
    }
  }

  const indicesu32 = new Uint32Array(indices);

  // 3: Create a shader module from the shaders template literal
  const shaderModule = device.createShaderModule({
    code: shaderString
  });

  context.configure({
    device: device,
    format: navigator.gpu.getPreferredCanvasFormat(),
    alphaMode: 'premultiplied'
  });

  // Create vertex buffer to contain vertex data
  const vertexBuffer = device.createBuffer({
    label: 'vertex buffer',
    size: verticesf32.byteLength, // make it big enough to store vertices in
    usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
  });

  // Copy the vertex data over to the GPUBuffer using the writeBuffer() utility function
  device.queue.writeBuffer(vertexBuffer, 0, verticesf32, 0, verticesf32.length);

  // Create a GPUVertexBufferLayout and GPURenderPipelineDescriptor to provide a definition of our render pipline
  const vertexBufferLayout: GPUVertexBufferLayout = {
    attributes: [{
      shaderLocation: 0,
      offset: 0,
      format: 'float32x3'
    }],
    arrayStride: 12,
    stepMode: 'vertex'
  };

  const indexBuffer = device.createBuffer({
    label: 'index buffer',
    size: indicesu32.byteLength,
    usage: GPUBufferUsage.INDEX | GPUBufferUsage.COPY_DST,
  });

  device.queue.writeBuffer(indexBuffer, 0, indicesu32);

  const uniforms = new Uniforms();
  const uniformBuffer = device.createBuffer({
    label: 'uniform buffer',
    size: uniforms.uniformBufferSize,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });

  // Create the actual render pipeline
  const pipelineDescriptor: GPURenderPipelineDescriptor = {
    vertex: {
      module: shaderModule,
      entryPoint: 'vertex_main',
      buffers: [vertexBufferLayout]
    },
    fragment: {
      module: shaderModule,
      entryPoint: 'fragment_main',
      targets: [{
        format: navigator.gpu.getPreferredCanvasFormat()
      }]
    },
    primitive: {
      topology: 'triangle-list'
    },
    layout: 'auto'
  };

  const renderPipeline = device.createRenderPipeline(pipelineDescriptor);

  const uniformBindGroup = device.createBindGroup({
    layout: renderPipeline.getBindGroupLayout(0),
    entries: [
      {
        binding: 0,
        resource: {
          buffer: uniformBuffer,
        },
      },
    ],
  });

  //////////////
  /// CAMERA ///
  //////////////
  const aspect = canvas.width / canvas.height;
  const projectionMatrix = mat4.perspective((2 * Math.PI) / 5, aspect, 0, 100.0);
  const camera = new Camera(START_POSITION);

  ////////////////
  /// CONTROLS ///
  ////////////////
  const controls = new Controls(canvas, (x: number, y: number) => camera.processMouseMovement(x, y));

  function getModelViewMatrix(speed: number) {
    camera.processControls(controls, speed);
    // Override camera position to always be at the start position when generating the transformation matrix
    const xyCameraPosOverride = vec2.fromValues(START_POSITION[0], START_POSITION[2]);
    return camera.getViewMatrix(xyCameraPosOverride);
  }

  function render() {
    const now = performance.now();
    const deltaTime = now - previousTime;
    previousTime = now;
    const t = (now / WATER_SPEED) % 1000;
    const modelViewMatrix = getModelViewMatrix(deltaTime * CONTROLS_SPEED);
    uniforms.projectionMatrix = projectionMatrix;
    uniforms.modelViewMatrix = modelViewMatrix;
    uniforms.fogColor = FOG_COLOR;
    uniforms.lightDirection = LIGHT_DIRECTION;
    uniforms.cameraPosition = camera.position;
    uniforms.config = new Float32Array([
      t,
      controls.fogOn ? 1.0 : 0.0,
      controls.lightsOn ? 1.0 : 0.0,
      controls.animationOn ? 1.0 : 0.0
    ]);
    const uniformBufferData = uniforms.getBufferData();
    device.queue.writeBuffer(
      uniformBuffer,
      0,
      uniformBufferData.data,
      uniformBufferData.dataOffset,
      uniformBufferData.size
    );


    // Create GPURenderPassDescriptor to tell WebGPU which texture to draw into, then initiate render pass
    const [r, g, b, a] = FOG_COLOR;
    const renderPassDescriptor: GPURenderPassDescriptor = {
      colorAttachments: [{
        clearValue: { r, g, b, a },
        loadOp: 'clear',
        storeOp: 'store',
        view: context.getCurrentTexture().createView()
      }]
    };

    // Create GPUCommandEncoder to issue commands to the GPU
    // Note: render pass descriptor, command encoder, etc. are destroyed after use, fresh one needed for each frame.
    const commandEncoder = device.createCommandEncoder();

    const passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor);

    // Draw the indices
    passEncoder.setPipeline(renderPipeline);
    passEncoder.setBindGroup(0, uniformBindGroup);
    passEncoder.setVertexBuffer(0, vertexBuffer);
    passEncoder.setIndexBuffer(indexBuffer, 'uint32');
    passEncoder.drawIndexed(indices.length);

    // End the render pass
    passEncoder.end();

    // End frame by passing array of command buffers to command queue for execution
    device.queue.submit([commandEncoder.finish()]);

    requestAnimationFrame(() => render());
  }

  render();
}
start()