import { mat4, vec4 } from "wgpu-matrix";

export class Uniforms {
  projectionMatrix: Float32Array = mat4.create();
  modelViewMatrix: Float32Array = mat4.create();
  lightDirection: Float32Array = vec4.create();
  fogColor: Float32Array = vec4.create();
  cameraPosition: Float32Array = vec4.create();
  config: Float32Array = vec4.create();

  uniformBufferSize = this.projectionMatrix.byteLength +
    this.modelViewMatrix.byteLength +
    this.fogColor.byteLength +
    this.lightDirection.byteLength +
    this.cameraPosition.byteLength +
    this.config.byteLength;

  #values: Float32Array = new Float32Array(this.uniformBufferSize / 4);

  getBufferData = () => {
    const uniforms = [
      this.projectionMatrix,
      this.modelViewMatrix,
      this.fogColor,
      this.lightDirection,
      this.cameraPosition,
      this.config
    ]
    let offset = 0;
    for (let i = 0; i < uniforms.length; i++) {
      this.#values.set(uniforms[i], offset);
      offset += uniforms[i].byteLength / 4;
    }
    return { data: this.#values.buffer, dataOffset: this.#values.byteOffset, size: this.#values.byteLength };
  }
}