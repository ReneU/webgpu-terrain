export class Controls {
  forwardKey = false
  backwardKey = false
  leftKey = false
  rightKey = false
  fogOn = true
  lightsOn = true
  animationOn = false

  constructor(canvas: HTMLCanvasElement, processMouseMovement: (x: number, y: number) => void) {
    document.addEventListener('keydown', (e: KeyboardEvent) => {
      switch (e.key) {
        case 'w':
          this.forwardKey = true;
          break;
        case 's':
          this.backwardKey = true;
          break;
        case 'a':
          this.leftKey = true;
          break;
        case 'd':
          this.rightKey = true;
          break;
        case '1':
          this.fogOn = !this.fogOn;
          break;
        case '2':
          this.lightsOn = !this.lightsOn;
          break;
        case '3':
          this.animationOn = !this.animationOn;
          break;
      }
    });

    document.addEventListener('keyup', (e: KeyboardEvent) => {
      switch (e.key) {
        case 'w':
          this.forwardKey = false;
          break;
        case 's':
          this.backwardKey = false;
          break;
        case 'a':
          this.leftKey = false;
          break;
        case 'd':
          this.rightKey = false;
          break;
        case 'Escape':
          canvas.removeEventListener('mousemove', onMouseMove);
          break;
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