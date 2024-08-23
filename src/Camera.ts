import { mat4, vec3, utils, vec4 } from 'wgpu-matrix';
import { Controls } from './Controls';

export class Camera {
  viewMatrix;
  position;
  front = vec3.fromValues();
  up = vec3.fromValues();
  worldUp = vec3.fromValues();
  right = vec3.fromValues();
  yaw = -90;
  pitch = -30;

  constructor(position: Float32Array, worldUp = new Float32Array([0, 1, 0])) {
    this.position = position;
    this.worldUp = worldUp;
    this.viewMatrix = mat4.identity();
    this.updateCameraVectors();
  }

  updateCameraVectors() {
    this.front = vec3.normalize(vec3.fromValues(
      Math.cos(utils.degToRad(this.yaw)) * Math.cos(utils.degToRad(this.pitch)),
      Math.sin(utils.degToRad(this.pitch)),
      Math.sin(utils.degToRad(this.yaw)) * Math.cos(utils.degToRad(this.pitch)))
    );
    this.right = vec3.normalize(vec3.cross(this.front, this.worldUp));  // normalize the vectors, because their length gets closer to 0 the more you look up or down which results in slower movement.
    this.up = vec3.normalize(vec3.cross(this.right, this.front));
  }

  processControls(controls: Controls, speed: number) {
    const velocity = speed;
    if (controls.forwardKey) {
      this.position = vec4.add(this.position, vec4.mul(this.front, vec4.fromValues(velocity, velocity, velocity)))
    }
    if (controls.backwardKey) {
      this.position = vec4.sub(this.position, vec4.mul(this.front, vec4.fromValues(velocity, velocity, velocity)))
    }
    if (controls.leftKey) {
      this.position = vec4.sub(this.position, vec4.mul(this.right, vec4.fromValues(velocity, velocity, velocity)))
    }
    if (controls.rightKey) {
      this.position = vec4.add(this.position, vec4.mul(this.right, vec4.fromValues(velocity, velocity, velocity)))
    }
  }

  processMouseMovement(xOffset: number, yOffset: number) {
    xOffset *= 0.5;
    yOffset *= 0.5;

    this.yaw += xOffset;
    this.pitch += yOffset;

    // make sure that when pitch is out of bounds, screen doesn't get flipped
    if (this.pitch > 89) {
      this.pitch = 89;
    } else if (this.pitch < -89) {
      this.pitch = -89;
    }

    // update front, right and up vectors using the updated Euler angles
    this.updateCameraVectors();
  }

  // Returns the view matrix with optional camera xy position override
  getViewMatrix(xyCameraPosOverride: Float32Array = new Float32Array([this.position[0], this.position[2]])) {
    const position = vec3.fromValues(xyCameraPosOverride[0], this.position[1], xyCameraPosOverride[2]);
    return mat4.lookAt(position, vec3.add(position, this.front), this.up);
  }
}