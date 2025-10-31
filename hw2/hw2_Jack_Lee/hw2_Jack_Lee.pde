import processing.sound.*;

SoundFile bg;
PImage birdImg;




// Game constants
float GRAVITY = 0.55;
float LIFT = -8.6;
float SCROLL = 3.2;
int COL_W = 90;
int SPAWN = 95;
int MIN_GAP_H = 140;
int MAX_GAP_H = 210;
int TEETH_COUNT = 3;
int TOOTH_LEN = 20;
int TOOTH_INSET = 8;


// Game state
float bx, by, br = 20, vy = 0;
ArrayList<TeethCol> cols;
int framesSinceSpawn = 0;
int score = 0;
boolean started = false;
boolean gameOver = false;

void setup() {
  size(480, 640);
  surface.setTitle("Flappy Bird in the Crocodile’s Mouth");
  textAlign(CENTER, CENTER);
  smooth(4);

  // Debug file checks
  println("data folder:", dataPath(""));
  println("bird exists?", new java.io.File(dataPath("Flying bird.png")).exists());
  println("music exists?", new java.io.File(dataPath("425137__nightwolfcfm__ogre-chase.mp3")).exists());

  birdImg = loadImage("Flying bird.png");
  if (birdImg == null) {
    println("ERROR: bird image not found");
  } else {
    birdImg.resize(60, 0);
  }

  bg = new SoundFile(this, "425137__nightwolfcfm__ogre-chase.mp3");
  resetGame(false);
}

void draw() {
  background(22, 28, 35);
  drawGround();

  float gy = guideRouteY();
  if (gy > 0) {
    stroke(255, 110);
    strokeWeight(2);
    for (int x = 0; x < width; x += 18) line(x, gy, x + 12, gy);
    noStroke();
  }

  if (!started) {
    drawBird();
    fill(255);
    textSize(20);
    text("Press R to start (music plays)", width/2, height/2 - 18);
    text("SPACE to flap", width/2, height/2 + 12);
    return;
  }

  if (!gameOver) {
    vy += GRAVITY;
    by += vy;
    framesSinceSpawn++;

    if (framesSinceSpawn >= SPAWN) {
      cols.add(new TeethCol());
      framesSinceSpawn = 0;
    }

    for (int i = cols.size() - 1; i >= 0; i--) {
      TeethCol c = cols.get(i);
      c.update();
      if (!c.scored && c.x + COL_W < bx) {
        score++;
        c.scored = true;
      }
      if (c.offscreen()) cols.remove(i);
    }

    if (by + br > height - groundH() || by - br < 0) gameOver = true;
    else {
      for (TeethCol c : cols) {
        if (c.overlapsX(bx, br) && c.collidesWithCircle(bx, by, br)) {
          gameOver = true;
          break;
        }
      }
    }

    if (gameOver && bg.isPlaying()) bg.stop();
  }

  for (TeethCol c : cols) c.show();
  drawBird();

  fill(255);
  textSize(36);
  text(score, width/2, 60);

  if (gameOver) {
    fill(0, 160);
    noStroke();
    rect(0, 0, width, height);
    fill(255);
    textSize(36);
    text("Game Over", width/2, height/2 - 26);
    textSize(20);
    text("Press R to restart", width/2, height/2 + 10);
  }
}

void keyPressed() {
  if (key == ' ' || key == 'w' || key == 'W') flap();
  if (key == 'r' || key == 'R') resetGame(true);
}

void flap() {
  if (!started || gameOver) return;
  vy = LIFT;
}

void resetGame(boolean startFromR) {
  bx = width * 0.3;
  by = height * 0.5;
  vy = 0;
  cols = new ArrayList<TeethCol>();
  framesSinceSpawn = 0;
  score = 0;
  gameOver = false;
  started = startFromR;

  if (startFromR) {
    if (bg.isPlaying()) bg.stop();
    bg.amp(0.25);
    bg.loop();
  }
}

void drawGround() {
  noStroke();
  fill(40, 110, 85);
  rect(0, height - groundH(), width, groundH());
}

int groundH() { return 80; }

void drawBird() {
  pushMatrix();
  translate(bx, by);
  float tilt = map(vy, -8, 8, -20, 20);
  rotate(radians(tilt));
  imageMode(CENTER);
  noTint();
  if (birdImg != null) image(birdImg, 0, 0);
  else { fill(255, 0, 0); ellipse(0, 0, br*2, br*2); }
  popMatrix();
}

float guideRouteY() {
  TeethCol next = null;
  float minX = Float.POSITIVE_INFINITY;
  for (TeethCol c : cols)
    if (c.x > bx && c.x < minX) { minX = c.x; next = c; }
  if (next == null) return -1;
  return next.gapY + next.gapHLocal * 0.5;
}

// =============================
// Teeth Column Class
// =============================
class TeethCol {
  float x, gapY;
  int gapHLocal;
  boolean scored = false;
  ArrayList<Tri> topTeeth = new ArrayList<Tri>();
  ArrayList<Tri> botTeeth = new ArrayList<Tri>();

  TeethCol() {
    x = width;
    float margin = 50;
    gapHLocal = int(random(MIN_GAP_H, MAX_GAP_H));
    gapY = random(margin + 40, height - groundH() - margin - gapHLocal);
    buildTeeth();
  }

  void update() { x -= SCROLL; }
  boolean offscreen() { return x + COL_W < 0; }
  boolean overlapsX(float bx, float br) { return (bx + br > x) && (bx - br < x + COL_W); }

  void show() {
    noStroke();
    fill(18, 22, 26);
    rect(x, 0, COL_W, gapY);
    rect(x, gapY + gapHLocal, COL_W, height - groundH() - (gapY + gapHLocal));

    fill(255);
    for (Tri t : topTeeth) triangle(x + t.x1, t.y1, x + t.x2, t.y2, x + t.x3, t.y3);
    for (Tri t : botTeeth) triangle(x + t.x1, t.y1, x + t.x2, t.y2, x + t.x3, t.y3);
  }

  void buildTeeth() {
    topTeeth.clear();
    botTeeth.clear();
    float cellW = COL_W / max(1, (float)TEETH_COUNT);
    float baseInset = min(TOOTH_INSET, cellW * 0.35);
    for (int i = 0; i < TEETH_COUNT; i++) {
      float bxL = i * cellW + baseInset;
      float bxR = (i + 1) * cellW - baseInset;
      float mid = 0.5 * (bxL + bxR);
      topTeeth.add(new Tri(bxL, gapY, bxR, gapY, mid, gapY + TOOTH_LEN));
      float byL = gapY + gapHLocal;
      botTeeth.add(new Tri(bxL, byL, bxR, byL, mid, byL - TOOTH_LEN));
    }
  }

  boolean collidesWithCircle(float cx, float cy, float r) {
    for (Tri t : topTeeth)
      if (circleTriangleHit(cx, cy, r, x + t.x1, t.y1, x + t.x2, t.y2, x + t.x3, t.y3)) return true;
    for (Tri t : botTeeth)
      if (circleTriangleHit(cx, cy, r, x + t.x1, t.y1, x + t.x2, t.y2, x + t.x3, t.y3)) return true;
    return false;
  }
}


// Triangle helper
class Tri {
  float x1, y1, x2, y2, x3, y3;
  Tri(float a, float b, float c, float d, float e, float f) {
    x1 = a; y1 = b; x2 = c; y2 = d; x3 = e; y3 = f;
  }
}



// Geometry helpers
boolean circleTriangleHit(float cx, float cy, float r, float x1, float y1, float x2, float y2, float x3, float y3) {
  if (pointInTri(cx, cy, x1, y1, x2, y2, x3, y3)) return true;
  if (distToSegment(cx, cy, x1, y1, x2, y2) <= r) return true;
  if (distToSegment(cx, cy, x2, y2, x3, y3) <= r) return true;
  if (distToSegment(cx, cy, x3, y3, x1, y1) <= r) return true;
  return false;
}

boolean pointInTri(float px, float py, float x1, float y1, float x2, float y2, float x3, float y3) {
  float dX = px - x3, dY = py - y3;
  float dX21 = x3 - x2, dY12 = y2 - y3;
  float D = dY12 * (x1 - x3) + dX21 * (y1 - y3);
  float s = dY12 * dX + dX21 * dY;
  float t = (y3 - y1) * dX + (x1 - x3) * dY;
  if (D < 0) return (s <= 0) && (t <= 0) && (s + t >= D);
  return (s >= 0) && (t >= 0) && (s + t <= D);
}

float distToSegment(float px, float py, float x1, float y1, float x2, float y2) {
  float vx = x2 - x1, vy = y2 - y1;
  float wx = px - x1, wy = py - y1;
  float vv = vx * vx + vy * vy;
  float tt = (vv == 0) ? 0 : (wx * vx + wy * vy) / vv;
  float t = constrain(tt, 0, 1);
  float projx = x1 + t * vx, projy = y1 + t * vy;
  return dist(px, py, projx, projy);
}
