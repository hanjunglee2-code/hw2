import processing.sound.*;   // audio

// ---------- Window & tuning ----------
final int   W = 480, H = 640;   // use surface API (no size())
final float GRAVITY = 0.55f;
final float LIFT    = -8.6f;
final float SCROLL  = 3.2f;
final int   COL_W   = 90;
final int   SPAWN   = 95;

// (Option A) random gap height range per column
final int   MIN_GAP_H = 140;
final int   MAX_GAP_H = 210;

// Teeth look (spaced crocodile fangs)
final int   TEETH_COUNT = 3;
final float TOOTH_LEN   = 20;
final float TOOTH_INSET = 8;

// ---------- Player (sprite + circle hitbox) ----------
float bx, by;          // position
float br = 20;         // radius for collisions
float vy = 0;          // vertical velocity
PImage birdImg;        // sprite

// ---------- Obstacles & state ----------
ArrayList<TeethCol> cols = new ArrayList<TeethCol>();
int framesSinceSpawn = 0, score = 0;
boolean started = false, gameOver = false, pendingInit = true;

// ---------- Audio ----------
SoundFile bg;
final String BG_FILE = "425137__nightwolfcfm__ogre-chase.mp3";

void setup() {
  surface.setResizable(true);
  surface.setTitle("Flappy Bird (sprite) + random gap height");
  surface.setSize(W, H);              // no size()
  textAlign(CENTER, CENTER);
  smooth(4);

  // Load sprite
  birdImg = loadImage("Flying bird.png");   // place in data/
  if (birdImg != null) birdImg.resize(60, 0); // ~60 px wide fits br≈20

  // Load music (don’t auto-play)
  bg = new SoundFile(this, BG_FILE);
  bg.amp(0.22);
  bg.rate(1.0);
}

void draw() {
  if (pendingInit) {
    if (width == W && height == H) { resetGame(false); pendingInit = false; }
    else { background(18); fill(255); text("Resizing window...", width/2, height/2); return; }
  }

  background(22, 28, 35);
  drawGround();

  // Route guide: dashed line at center of the NEXT column's local gap height
  float gy = guideRouteY();
  if (gy > 0) {
    stroke(255, 110); strokeWeight(2);
    for (int x = 0; x < width; x += 18) line(x, gy, x + 12, gy);
    noStroke();
  }

  if (!started) {
    drawBird();
    fill(255);
    textSize(20);
    text("Press R to start (music plays)", width/2, height/2 - 18);
    text("SPACE / click to flap",        width/2, height/2 + 12);
    return;
  }

  if (!gameOver) {
    // Physics
    vy += GRAVITY;
    by += vy;

    // Spawn obstacles
    framesSinceSpawn++;
    if (framesSinceSpawn >= SPAWN) { cols.add(new TeethCol()); framesSinceSpawn = 0; }

    // Move/score/cull
    for (int i = cols.size() - 1; i >= 0; i--) {
      TeethCol c = cols.get(i);
      c.update();
      if (!c.scored && c.x + COL_W < bx) { score++; c.scored = true; }
      if (c.offscreen()) cols.remove(i);
    }

    // World collisions
    if (by + br > height - groundH() || by - br < 0) gameOver = true;
    else {
      for (TeethCol c : cols) {
        if (c.overlapsX(bx, br) && c.collidesWithCircle(bx, by, br)) {
          gameOver = true; break;
        }
      }
    }

    if (gameOver && bg.isPlaying()) bg.stop();
  }

  // Render
  for (TeethCol c : cols) c.show();
  drawBird();

  // UI
  fill(255); textSize(36); text(str(score), width/2, 60);
  if (gameOver) {
    fill(0, 160); rect(0, 0, width, height);
    fill(255); textSize(36); text("Game Over", width/2, height/2 - 26);
    textSize(20); text("Press R to restart", width/2, height/2 + 10);
  }
}

// ---------- Input ----------
void keyPressed() {
  if (key == ' ' || key == 'w' || key == 'W') flap();
  if (key == 'r' || key == 'R') resetGame(true);   // also starts music
}
void mousePressed() { flap(); }
void flap() { if (!started || gameOver) return; vy = LIFT; }

// ---------- Helpers ----------
void resetGame(boolean fromR) {
  bx = width * 0.30f;
  by = height * 0.50f;
  vy = 0;
  cols.clear(); framesSinceSpawn = 0; score = 0; gameOver = false; started = fromR;
  if (fromR) { if (bg.isPlaying()) bg.stop(); bg.play(); } // use bg.loop() if you prefer looping
}

float groundH() { return 80; }
void drawGround() { noStroke(); fill(40,110,85); rect(0, height - groundH(), width, groundH()); }

void drawBird() {
  pushMatrix();
  translate(bx, by);
  float tilt = map(vy, -8, 8, -20, 20); // tilt by velocity
  rotate(radians(tilt));
  imageMode(CENTER);
  if (birdImg != null) image(birdImg, 0, 0);
  else { noStroke(); fill(240,240,255); ellipse(0, 0, br*2, br*2); } // fallback
  popMatrix();
}

// Return y for guide line using next column's *local* gap height
float guideRouteY() {
  TeethCol next = null; float minX = Float.MAX_VALUE;
  for (TeethCol c : cols) if (c.x > bx && c.x < minX) { minX = c.x; next = c; }
  if (next == null) return -1;
  return next.gapY + next.gapHLocal * 0.5f;
}

// ================= Obstacles (with per-column random gap) =================
class Tri { float x1,y1,x2,y2,x3,y3;
  Tri(float a,float b,float c,float d,float e,float f){ x1=a;y1=b;x2=c;y2=d;x3=e;y3=f; }
}

class TeethCol {
  float x, gapY;
  int gapHLocal;                   // <-- per-column randomized gap height
  boolean scored = false;
  ArrayList<Tri> topTeeth = new ArrayList<Tri>();
  ArrayList<Tri> botTeeth = new ArrayList<Tri>();

  TeethCol() {
    x = width;
    float margin = 50;
    // choose a local gap height first, then pick a Y that keeps it on-screen
    gapHLocal = int(random(MIN_GAP_H, MAX_GAP_H));             // 140..210 px
    gapY = random(margin + 40, height - groundH() - margin - gapHLocal);
    buildTeeth();
  }

  void update() { x -= SCROLL; }
  boolean offscreen() { return x + COL_W < 0; }
  boolean overlapsX(float bx_, float br_) { return (bx_ + br_ > x) && (bx_ - br_ < x + COL_W); }

  void show() {
    // black pillars above/below the local gap
    noStroke(); fill(18,22,26);
    rect(x, 0, COL_W, gapY);
    rect(x, gapY + gapHLocal, COL_W, height - groundH() - (gapY + gapHLocal));

    // white teeth rows
    fill(255); noStroke();
    for (Tri t : topTeeth)  triangle(x + t.x1, t.y1, x + t.x2, t.y2, x + t.x3, t.y3);
    for (Tri t : botTeeth)  triangle(x + t.x1, t.y1, x + t.x2, t.y2, x + t.x3, t.y3);

    // outlines for readability
    noFill(); stroke(255,60);
    rect(x, 0, COL_W, gapY);
    rect(x, gapY + gapHLocal, COL_W, height - groundH() - (gapY + gapHLocal));
    noStroke();
  }

  void buildTeeth() {
    topTeeth.clear(); botTeeth.clear();
    float cellW = COL_W / max(1, (float)TEETH_COUNT);
    float baseInset = min(TOOTH_INSET, cellW * 0.35f);
    for (int i = 0; i < TEETH_COUNT; i++) {
      float bxL = i * cellW + baseInset;
      float bxR = (i + 1) * cellW - baseInset;
      float mid = 0.5f * (bxL + bxR);
      // top row: tips point down into gap
      topTeeth.add(new Tri(bxL, gapY, bxR, gapY, mid, gapY + TOOTH_LEN));
      // bottom row: tips point up into gap (using local gap height)
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

// ---------- Geometry helpers ----------
boolean circleTriangleHit(float cx,float cy,float r,
                          float x1,float y1,float x2,float y2,float x3,float y3) {
  if (pointInTri(cx, cy, x1,y1,x2,y2,x3,y3)) return true;
  if (distToSegment(cx, cy, x1,y1, x2,y2) <= r) return true;
  if (distToSegment(cx, cy, x2,y2, x3,y3) <= r) return true;
  if (distToSegment(cx, cy, x3,y3, x1,y1) <= r) return true;
  if (dist(cx, cy, x1, y1) <= r) return true;
  if (dist(cx, cy, x2, y2) <= r) return true;
  if (dist(cx, cy, x3, y3) <= r) return true;
  return false;
}

boolean pointInTri(float px,float py, float x1,float y1,float x2,float y2,float x3,float y3){
  float dX = px - x3, dY = py - y3;
  float dX21 = x3 - x2, dY12 = y2 - y3;
  float D = dY12*(x1 - x3) + dX21*(y1 - y3);
  float s = dY12*dX + dX21*dY;
  float t = (y3 - y1)*dX + (x1 - x3)*dY;
  if (D < 0) return (s <= 0) && (t <= 0) && (s + t >= D);
  return (s >= 0) && (t >= 0) && (s + t <= D);
}

float distToSegment(float px,float py, float x1,float y1,float x2,float y2){
  float vx = x2 - x1, vy = y2 - y1;
  float wx = px - x1, wy = py - y1;
  float vv = vx*vx + vy*vy;
  float t = (vv == 0) ? 0 : (wx*vx + wy*vy) / vv;
  t = constrain(t, 0, 1);
  float projx = x1 + t*vx, projy = y1 + t*vy;
  return dist(px, py, projx, projy);
}
