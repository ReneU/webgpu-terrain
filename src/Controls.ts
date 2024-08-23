export class Controls {
  forwardKey = false
  backwardKey = false
  leftKey = false
  rightKey = false
  fogOn = true
  lightsOn = true

  constructor(canvas: HTMLCanvasElement, processMouseMovement: (x: number, y: number) => void) {
    document.addEventListener('keydown', (e: KeyboardEvent) => {
      const { key, altKey, ctrlKey } = e;
      if (key === 'w') {
        this.forwardKey = true;
      } else if (key === 's') {
        this.backwardKey = true;
      } else if (key === 'a') {
        this.leftKey = true;
      } else if (key === 'd') {
        this.rightKey = true;
      }

      if (ctrlKey) {
        this.fogOn = !this.fogOn;
      }

      if (altKey) {
        this.lightsOn = !this.lightsOn;
      }
    });

    document.addEventListener('keyup', (e: KeyboardEvent) => {
      const { key } = e;
      if (key === 'w') {
        this.forwardKey = false;
      } else if (key === 's') {
        this.backwardKey = false;
      } else if (key === 'a') {
        this.leftKey = false;
      } else if (key === 'd') {
        this.rightKey = false;
      } else if (key === 'Escape') {
        canvas.removeEventListener('mousemove', onMouseMove);
      }
    });

    const onMouseMove = (e: MouseEvent) => {
      processMouseMovement(e.movementX, -e.movementY);
    }

    canvas.addEventListener('click', () => {
      canvas.requestPointerLock();
      canvas.addEventListener('mousemove', onMouseMove);
    })
  }
}