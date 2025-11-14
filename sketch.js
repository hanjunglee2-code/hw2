/* Flappy — p5.js port
   - Bird sprite + triangle teeth obstacles
   - Random gap Y and random gap height per column
   - Route guide line
   - Music starts when you press R, stops when Game Over
   Controls: SPACE / mouse = flap, R = restart (and also start music)
*/

// ---------- window & tuning ----------
const W = 480, H = 640;
const GRAVITY = 0.55;
const LIFT    = -8.6;
const SCROLL  = 3.2;
const COL_W   = 90;
const SPAWN   = 95;

// random gap height per column
const MIN_GAP_H = 140;
const MAX_GAP_H = 210;

// teeth styling
const TEETH_COUNT = 3;
const TOOTH_LEN   = 20;
const TOOTH_INSET = 8;

// assets
let birdImg, bg;

// game state
let bx, by, br = 20, vy = 0;
let cols = [];
let framesSinceSpawn = 0, score = 0;
let started = false, gameOver = false;

// ---------- preload assets ----------
function preload() {
  // exact filenames (space included)
  birdImg = loadImage('Flying bird.png');
  soundFormats('mp3', 'wav');
  bg = loadSound('425137__nightwolfcfm__ogre-chase.mp3');
}

function setup() {
  createCanvas(W, H);
  imageMode(CENTER);
  textAlign(CENTER, CENTER);

  // resize sprite similar to Processing version
  if (birdImg) {
    const targetW = 60;
    const s = targetW / birdImg.width;
    birdImg.resize(targetW, Math.round(birdImg.height * s));
  }
  resetGame(false);
}

function draw() {
  background(22, 28, 35);
  drawGround();

  // route guide at center of next column's local gap height
  const gy = guideRouteY();
  if (gy > 0) {
    stroke(255, 110); strokeWeight(2);
    for (let x = 0; x < width; x += 18) line(x, gy, x + 12, gy);
    noStroke();
  }

  if (!started) {
    drawBird();
    fill(255); textSize(20);
    text('Press R to start (music plays)', width/2, height/2 - 18);
    text('SPACE / click to flap',           width/2, height/2 + 12);
    return;
  }

  if (!gameOver) {
    // physics
    vy += GRAVITY;
    by += vy;

    // spawn columns
    framesSinceSpawn++;
    if (framesSinceSpawn >= SPAWN) {
      cols.push(new TeethCol());
      framesSinceSpawn = 0;
    }

    // update columns
    for (let i = cols.length - 1; i >= 0; i--) {
      const c = cols[i];
      c.update();
      if (!c.scored && c.x + COL_W < bx) { score++; c.scored = true; }
      if (c.offscreen()) cols.splice(i, 1);
    }

    // world collisions
    if (by + br > height - groundH() || by - br < 0) gameOver = true;
    else {
      for (const c of cols) {
        if (c.overlapsX(bx, br) && c.collidesWithCircle(bx, by, br)) {
          gameOver = true; break;
        }
      }
    }

    // stop music on game over
    if (gameOver && bg.isPlaying()) bg.stop();
  }

  // render
  for (const c of cols) c.show();
  drawBird();

  // UI
  fill(255); textSize(36); text(String(score), width/2, 60);
  if (gameOver) {
    fill(0, 160); noStroke(); rect(0, 0, width, height);
    fill(255); textSize(36); text('Game Over', width/2, height/2 - 26);
    textSize(20);           text('Press R to restart', width/2, height/2 + 10);
  }
}

// ---------- input ----------
function keyPressed() {
  if (key === ' ' || key === 'W' || key === 'w') flap();
  if (key === 'R' || key === 'r') {
    // user gesture required for audio on the web
    userStartAudio().then(() => resetGame(true));
  }
}
function mousePressed() { flap(); }
function flap() {
  if (!started || gameOver) return;
  vy = LIFT;
}

// ---------- helpers ----------
function resetGame(startFromR) {
  bx = width * 0.30;
  by = height * 0.50;
  vy = 0;
  cols = [];
  framesSinceSpawn = 0;
  score = 0;
  gameOver = false;
  started = !!startFromR;

  if (startFromR) {
    if (bg.isPlaying()) bg.stop();
    bg.setVolume(0.25);
    bg.loop(); // continuous like your Processing version
  }
}

function groundH() { return 80; }
function drawGround() {
  noStroke(); fill(40,110,85);
  rect(0, height - groundH(), width, groundH());
}

function drawBird() {
  push();
  translate(bx, by);
  const tilt = map(vy, -8, 8, -20, 20);
  rotate(radians(tilt));
  noTint();
  if (birdImg) image(birdImg, 0, 0);
  else { noStroke(); fill(255,0,0); ellipse(0,0, br*2, br*2); }
  pop();
}

function guideRouteY() {
  let next = null; let minX = Number.POSITIVE_INFINITY;
  for (const c of cols) if (c.x > bx && c.x < minX) { minX = c.x; next = c; }
  if (!next) return -1;
  return next.gapY + next.gapHLocal * 0.5;
}

// ================= obstacles =================
class Tri {
  constructor(a,b,c,d,e,f){ this.x1=a; this.y1=b; this.x2=c; this.y2=d; this.x3=e; this.y3=f; }
}

class TeethCol {
  constructor() {
    this.x = width;
    const margin = 50;
    this.gapHLocal = int(random(MIN_GAP_H, MAX_GAP_H));
    this.gapY = random(margin + 40, height - groundH() - margin - this.gapHLocal);
    this.scored = false;
    this.topTeeth = [];
    this.botTeeth = [];
    this.buildTeeth();
  }
  update() { this.x -= SCROLL; }
  offscreen() { return this.x + COL_W < 0; }
  overlapsX(bx, br) { return (bx + br > this.x) && (bx - br < this.x + COL_W); }

  show() {
    // black pillars above/below local gap
    noStroke(); fill(18,22,26);
    rect(this.x, 0, COL_W, this.gapY);
    rect(this.x, this.gapY + this.gapHLocal, COL_W, height - groundH() - (this.gapY + this.gapHLocal));

    // white teeth
    fill(255); noStroke();
    for (const t of this.topTeeth) triangle(this.x + t.x1, t.y1, this.x + t.x2, t.y2, this.x + t.x3, t.y3);
    for (const t of this.botTeeth) triangle(this.x + t.x1, t.y1, this.x + t.x2, t.y2, this.x + t.x3, t.y3);

    // subtle outlines (optional)
    noFill(); stroke(255,60);
    rect(this.x, 0, COL_W, this.gapY);
    rect(this.x, this.gapY + this.gapHLocal, COL_W, height - groundH() - (this.gapY + this.gapHLocal));
    noStroke();
  }

  buildTeeth() {
    this.topTeeth = []; this.botTeeth = [];
    const cellW = COL_W / max(1, TEETH_COUNT);
    const baseInset = min(TOOTH_INSET, cellW * 0.35);
    for (let i = 0; i < TEETH_COUNT; i++) {
      const bxL = i * cellW + baseInset;
      const bxR = (i + 1) * cellW - baseInset;
      const mid = 0.5 * (bxL + bxR);
      // top row: tips down
      this.topTeeth.push(new Tri(bxL, this.gapY, bxR, this.gapY, mid, this.gapY + TOOTH_LEN));
      // bottom row: tips up
      const byL = this.gapY + this.gapHLocal;
      this.botTeeth.push(new Tri(bxL, byL, bxR, byL, mid, byL - TOOTH_LEN));
    }
  }

  collidesWithCircle(cx, cy, r) {
    for (const t of this.topTeeth)
      if (circleTriangleHit(cx, cy, r, this.x + t.x1, t.y1, this.x + t.x2, t.y2, this.x + t.x3, t.y3)) return true;
    for (const t of this.botTeeth)
      if (circleTriangleHit(cx, cy, r, this.x + t.x1, t.y1, this.x + t.x2, t.y2, this.x + t.x3, t.y3)) return true;
    return false;
  }
}

// ---------- geometry helpers ----------
function circleTriangleHit(cx, cy, r, x1, y1, x2, y2, x3, y3) {
  if (pointInTri(cx, cy, x1, y1, x2, y2, x3, y3)) return true;
  if (distToSegment(cx, cy, x1, y1, x2, y2) <= r) return true;
  if (distToSegment(cx, cy, x2, y2, x3, y3) <= r) return true;
  if (distToSegment(cx, cy, x3, y3, x1, y1) <= r) return true;
  if (dist(cx, cy, x1, y1) <= r) return true;
  if (dist(cx, cy, x2, y2) <= r) return true;
  if (dist(cx, cy, x3, y3) <= r) return true;
  return false;
}

function pointInTri(px, py, x1, y1, x2, y2, x3, y3) {
  const dX = px - x3, dY = py - y3;
  const dX21 = x3 - x2, dY12 = y2 - y3;
  const D = dY12*(x1 - x3) + dX21*(y1 - y3);
  const s = dY12*dX + dX21*dY;
  const t = (y3 - y1)*dX + (x1 - x3)*dY;
  if (D < 0) return (s <= 0) && (t <= 0) && (s + t >= D);
  return (s >= 0) && (t >= 0) && (s + t <= D);
}

function distToSegment(px, py, x1, y1, x2, y2) {
  const vx = x2 - x1, vy = y2 - y1;
  const wx = px - x1, wy = py - y1;
  const vv = vx*vx + vy*vy;
  const tt = (vv === 0) ? 0 : (wx*vx + wy*vy) / vv;
  const t = constrain(tt, 0, 1);
  const projx = x1 + t*vx, projy = y1 + t*vy;
  return dist(px, py, projx, projy);
}
