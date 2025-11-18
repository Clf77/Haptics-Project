// Haptic Lathe Simulator GUI
// - Hover highlight (light gray)
// - Selected state (green)
// - Stock dimensions driven by inches -> pixels

int W = 1280;
int H = 720;

int headerH    = 60;
int footerH    = 60;
int leftPanelW = 220;
int rightPanelW = 330;
int padding    = 10;

// Colors (will be set in setup)
int bgColor;
int panelStroke;
int panelFill;
int headerFill;
int footerFill;
int accentFill;

// ----- Stock dimensions (change these in inches) -----
float stockLengthIn   = 9.0;   // length of stock in inches
float stockDiameterIn = 1.25;  // diameter of stock in inches
float pxPerIn         = 60.0;  // scale factor: pixels per inch

// ----- Button state booleans -----
// Training scenario
boolean facingSelected       = true;
boolean turnDiaSelected      = false;
boolean boringSelected       = false;
boolean customSelected       = false;

// Skill level
boolean beginnerSelected     = true;
boolean intermediateSelected = false;
boolean advancedSelected     = false;

// Controls
boolean resetSelected        = false;
boolean zeroSelected         = false;
boolean pathSelected         = false;

// ----- Momentary button flash timing (ms) -----
int flashDuration    = 200;   // how long buttons stay green after click
int resetFlashStart  = -1000;
int zeroXFlashStart  = -1000;
int zeroZFlashStart  = -1000;


// ----- Cutting parameter values (editable) -----
String spindleStr = "0";      // displayed / editable text
String feedStr    = "0.000";
String docStr     = "0.000";

float spindleRPM = 0;
float feedRate   = 0;
float depthCut   = 0;

// which field is active? 0 = none, 1 = spindle, 2 = feed, 3 = doc
int activeField = 0;

// bounding boxes for clicking on parameter lines
float rpmBoxX, rpmBoxY, rpmBoxW, rpmBoxH;
float feedBoxX, feedBoxY, feedBoxW, feedBoxH;
float docBoxX, docBoxY, docBoxW, docBoxH;

// ----- Tool tip position (in pixels + inches) -----
float toolTipXpx = 0;
float toolTipYpx = 0;

// raw positions in inches (from geometry)
float rawXIn = 0;   // radial / X
float rawZIn = 0;   // axial / Z

// zero offsets (what Zero X / Zero Z set)
float xZeroOffsetIn = 0;
float zZeroOffsetIn = 0;

// displayed positions (raw - offset)
float xPosIn = 0;
float zPosIn = 0;



// ----------------------------------------------------
// Processing 4: window size must be set in settings()
// ----------------------------------------------------

void setup() {
  size(1280, 720);
  smooth();
  textAlign(LEFT, CENTER);
  textFont(createFont("Arial", 14));

  // Define colors now that the window exists
  bgColor     = color(245);
  panelStroke = color(0);
  panelFill   = color(255);
  headerFill  = color(230);
  footerFill  = color(230);
  accentFill  = color(240);
}


void draw() {
  background(bgColor);
  drawHeader();
  drawFooter();
  drawLeftPanel();
  drawMainView();   // compute tool tip + X/Z first
  drawRightPanel(); // then use them in live readouts
}


// ----------------------------------------------------
// HEADER
// ----------------------------------------------------
void drawHeader() {
  fill(headerFill);
  stroke(panelStroke);
  rect(0, 0, W, headerH);
  
  fill(0);
  textSize(22);
  text("Haptic Lathe Simulator", padding, headerH / 2);

  // Mode toggle visual (static for now)
  float toggleW = 220;
  float toggleH = 30;
  float toggleX = W - toggleW - padding;
  float toggleY = headerH / 2 - toggleH / 2;
  
  // Lathe mode
  fill(255);
  stroke(0);
  rect(toggleX, toggleY, toggleW / 2, toggleH);
  fill(0, 200, 0); 
  //fill(0);
  textSize(13);
  textAlign(CENTER, CENTER);
  text("Lathe Mode", toggleX + toggleW / 4, toggleY + toggleH / 2);
  
  // Mill mode (stretch goal)
  //fill(255);
  //stroke(0);
  //rect(toggleX + toggleW / 2, toggleY, toggleW / 2, toggleH);
  //fill(0);
  //text("Mill Mode (stretch)", toggleX + 3 * toggleW / 4, toggleY + toggleH / 2);
  
  textAlign(LEFT, CENTER);
}

// ----------------------------------------------------
// FOOTER
// ----------------------------------------------------
void drawFooter() {
  float y = H - footerH;
  fill(footerFill);
  stroke(panelStroke);
  rect(0, y, W, footerH);
  
  fill(0);
  textSize(14);
  text("Status: Ready • No cut in progress • Haptic device connected",
       padding, y + footerH / 2);
}

// ----------------------------------------------------
// LEFT PANEL (buttons with hover + selected states)
// ----------------------------------------------------
void drawLeftPanel() {
  float x = 0;
  float y = headerH;
  float h = H - headerH - footerH;
  
  fill(panelFill);
  stroke(panelStroke);
  rect(x, y, leftPanelW, h);
  
  float innerX = x + padding;
  float innerY = y + padding;
  
  // ----- Training Scenario -----
  drawSubPanelTitle(innerX, innerY, "Training Scenario");
  innerY += 25;
  drawPillButton(innerX, innerY, "Facing", facingSelected);
  innerY += 30;
  drawPillButton(innerX, innerY, "Turn to Diameter", turnDiaSelected);
  innerY += 30;
  drawPillButton(innerX, innerY, "Boring", boringSelected);
  innerY += 30;
  //drawPillButton(innerX, innerY, "Custom / Free Practice", customSelected);
  
  // ----- Skill Level -----
  innerY += 45;
  drawSubPanelTitle(innerX, innerY, "Skill Level");
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Beginner",     beginnerSelected);
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Intermediate", intermediateSelected);
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Advanced",     advancedSelected);
  
  // ----- Controls -----
  innerY += 45;
  drawSubPanelTitle(innerX, innerY, "Controls");

  // Reset Workpiece (momentary flash)
  innerY += 25;
  boolean resetOn = (millis() - resetFlashStart) < flashDuration;
  drawOutlinedButton(innerX, innerY, "Reset Workpiece", resetOn);

  // Zero X (momentary flash)
  innerY += 25;
  boolean zeroXOn = (millis() - zeroXFlashStart) < flashDuration;
  drawOutlinedButton(innerX, innerY, "Zero X", zeroXOn);

  // Zero Z (momentary flash)
  innerY += 25;
  boolean zeroZOn = (millis() - zeroZFlashStart) < flashDuration;
  drawOutlinedButton(innerX, innerY, "Zero Z", zeroZOn);

  // Show Toolpath (remains a toggle)
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Show Toolpath", pathSelected);

}

// ----------------------------------------------------
// RIGHT PANEL (static info)
// ----------------------------------------------------
void drawRightPanel() {
  float x = W - rightPanelW;
  float y = headerH;
  float h = H - headerH - footerH;
  
  fill(panelFill);
  stroke(panelStroke);
  rect(x, y, rightPanelW, h);
  
  float innerX = x + padding;
  float innerY = y + padding;
  float sectionW = rightPanelW - 2 * padding;
  
  // Live readouts
  drawSubPanelBox(innerX, innerY, sectionW, 140, "Live Readouts");
  float lineY = innerY + 40;
  float lineH = 22;
  fill(0);
  textSize(14);
  text("X Position:   " + nfp(xPosIn, 1, 3) + " in", innerX + 10, lineY); lineY += lineH;
  text("Z Position:   " + nfp(zPosIn, 1, 3) + " in", innerX + 10, lineY); lineY += lineH;
  text("Tool Load Fx: 0.0 N",     innerX + 10, lineY); lineY += lineH;
  text("Tool Load Fz: 0.0 N",     innerX + 10, lineY); lineY += lineH;
  
  innerY += 150;
  
  // Cutting parameters (now editable)
  drawSubPanelBox(innerX, innerY, sectionW, 170, "Cutting Parameters");
  lineY = innerY + 40;
  lineH = 22;
  textSize(14);
  
  // ----- Spindle Speed field -----
  rpmBoxX = innerX + 5;
  rpmBoxY = lineY - lineH / 2;
  rpmBoxW = sectionW - 10;
  rpmBoxH = lineH;

  if (activeField == 1) {
    fill(230);
    noStroke();
    rect(rpmBoxX, rpmBoxY, rpmBoxW, rpmBoxH);
  }

  fill(0);
  text("Spindle Speed [RPM]:   " + spindleStr, innerX + 10, lineY);
  lineY += lineH;
  
  // ----- Feed Rate field -----
  feedBoxX = innerX + 5;
  feedBoxY = lineY - lineH / 2;
  feedBoxW = sectionW - 10;
  feedBoxH = lineH;

  if (activeField == 2) {
    fill(230);
    noStroke();
    rect(feedBoxX, feedBoxY, feedBoxW, feedBoxH);
  }

  fill(0);
  text("Feed Rate [in/rev]:    " + feedStr, innerX + 10, lineY);
  lineY += lineH;

  // ----- Depth of Cut field -----
  docBoxX = innerX + 5;
  docBoxY = lineY - lineH / 2;
  docBoxW = sectionW - 10;
  docBoxH = lineH;

  if (activeField == 3) {
    fill(230);
    noStroke();
    rect(docBoxX, docBoxY, docBoxW, docBoxH);
  }

  fill(0);
  text("Depth of Cut [in]:     " + docStr, innerX + 10, lineY);
  lineY += lineH;

  // Material & coolant (static for now)
  fill(0);
  text("Material: Mild Steel", innerX + 10, lineY); lineY += lineH;
  text("Coolant: On / Off",    innerX + 10, lineY);
  
    innerY += 190;
  
  // ---------- Tolerance summary (depends on scenario + skill level) ----------
  drawSubPanelBox(innerX, innerY, sectionW, 120, "Tolerance Summary");
  lineY = innerY + 40;

  // Skill-based tolerance (same logic as in drawMainView)
  boolean anySkill2 = beginnerSelected || intermediateSelected || advancedSelected;
  String tolStr2;
  if (!anySkill2 || beginnerSelected) {
    tolStr2 = "± 0.010 in";     // Beginner or none selected yet
  } else if (intermediateSelected) {
    tolStr2 = "± 0.005 in";     // Intermediate
  } else {
    tolStr2 = "± 0.002 in";     // Advanced
  }

  // Scenario-based operation + target text
  boolean anyScenario2 = facingSelected || turnDiaSelected || boringSelected || customSelected;
  String currentOpStr;
  String targetStr;
  String currentStr;

  if (facingSelected || !anyScenario2) {
    // Facing: overall length
    currentOpStr = "Facing to overall length";
    targetStr    = "Target: L = 4.000 " + tolStr2;
    currentStr   = "Current: L = 4.012";   // placeholder example
  } else if (turnDiaSelected) {
    // Turn to diameter: external shoulder
    currentOpStr = "Turn shoulder to Ø 1.000 in";
    targetStr    = "Target: Ø 1.000 " + tolStr2;
    currentStr   = "Current: Ø 1.012";
  } else if (boringSelected) {
    // Boring: internal diameter
    currentOpStr = "Bore ID to Ø 1.000 in";
    targetStr    = "Target: Ø 1.000 " + tolStr2;
    currentStr   = "Current: Ø 1.006";
  } else {
    // Custom / fallback
    currentOpStr = "User-defined operation";
    targetStr    = "Target: per setup (" + tolStr2 + ")";
    currentStr   = "Current: Measurement TBD";
  }

  text("Current Operation: " + currentOpStr, innerX + 10, lineY); lineY += lineH;
  text(targetStr,                              innerX + 10, lineY); lineY += lineH;
  text(currentStr,                             innerX + 10, lineY);

}

// ----------------------------------------------------
// MAIN VIEW (virtual lathe + inch-based stock)
// ----------------------------------------------------
void drawMainView() {
  float x = leftPanelW;
  float y = headerH;
  float w = W - leftPanelW - rightPanelW;
  float h = H - headerH - footerH;
  
  fill(panelFill);
  stroke(panelStroke);
  rect(x, y, w, h);
  
  float innerX = x + padding;
  float innerY = y + padding;
  float innerW = w - 2 * padding;
  float innerH = h - 2 * padding;

  // ---------- Decide what to show in Drawing / Tolerances View ----------
    // ---------- Decide what to show in Drawing / Tolerances View ----------
  // (Also updates stockLengthIn / stockDiameterIn used for the workspace)
  String stockLine;
  String opLine;
  String datumLine;

  boolean anyScenario = facingSelected || turnDiaSelected || boringSelected || customSelected;

  // ----- Skill-based tolerance string -----
  boolean anySkill = beginnerSelected || intermediateSelected || advancedSelected;
  String tolStr;

  if (!anySkill || beginnerSelected) {
    tolStr = "± 0.010 in";      // Beginner (or none picked yet)
  } else if (intermediateSelected) {
    tolStr = "± 0.005 in";      // Intermediate
  } else {
    tolStr = "± 0.002 in";      // Advanced
  }

  // ----- Operation-dependent text, using tolStr -----
  if (facingSelected || !anyScenario) {
    // FACING MODE
    stockDiameterIn = 1.25;
    stockLengthIn   = 4.50;
    stockLine = "• Stock: Ø " + nf(stockDiameterIn, 1, 2) + " in x " +
                nf(stockLengthIn, 1, 2) + " in";
    opLine    = "• Operation: Facing to overall length 4.000 " + tolStr;
    datumLine = "• Datum: Chuck face (Z = 0.000 in)";
  } else if (turnDiaSelected) {
    // TURN TO DIAMETER
    stockDiameterIn = 1.25;
    stockLengthIn   = 4.00;
    stockLine = "• Stock: Ø " + nf(stockDiameterIn, 1, 2) + " in x " +
                nf(stockLengthIn, 1, 2) + " in";
    opLine    = "• Operation: Turn shoulder to Ø 1.000 " + tolStr;
    datumLine = "• Datum: Shoulder location from Z = 0.000 in";
  } else if (boringSelected) {
    // BORING
    stockDiameterIn = 2.00;
    stockLengthIn   = 3.00;
    stockLine = "• Stock: Ø " + nf(stockDiameterIn, 1, 2) + " in x " +
                nf(stockLengthIn, 1, 2) + " in (pre-drilled)";
    opLine    = "• Operation: Bore ID to Ø 1.000 " + tolStr;
    datumLine = "• Datum: Bore start at Z = 0.000 in";
  } else {
    // CUSTOM / fallback
    stockDiameterIn = 1.50;
    stockLengthIn   = 4.00;
    stockLine = "• Stock: Ø " + nf(stockDiameterIn, 1, 2) + " in x " +
                nf(stockLengthIn, 1, 2) + " in";
    opLine    = "• Operation: User-defined (custom)";
    datumLine = "• Datum: Defined per setup";
  }

  
  // --- Drawing section (top) ---
  float drawingH = 160;
  fill(accentFill);
  rect(innerX, innerY, innerW, drawingH);
  fill(0);
  textSize(16);
  text("Drawing / Tolerances View", innerX + 10, innerY + 20);
  textSize(12);
  text(stockLine + "\n" + opLine + "\n" + datumLine,
       innerX + 10, innerY + 55);
  
  // Drawing thumbnail
  float printX = innerX + innerW - 260;
  float printY = innerY + 20;
  float printW = 240;
  float printH = drawingH - 40;
  noFill();
  stroke(0);
  rect(printX, printY, printW, printH);
  line(printX + 40, printY + 20, printX + printW - 20, printY + 20);
  textSize(10);
  text("Lathe Part Drawing (wireframe)", printX + 10, printY + 12);
  

  // --- Workspace (bottom) ---
  float workspaceY = innerY + drawingH + padding;
  float workspaceH = innerH - drawingH - padding;
  fill(255);
  rect(innerX, workspaceY, innerW, workspaceH);
  
  fill(0);
  textSize(16);
  text("Virtual Lathe Workspace", innerX + 10, workspaceY + 20);
  
  // Lathe geometry
  float centerY = workspaceY + workspaceH * 0.40;
  float chuckX  = innerX + 100;
  float chuckW  = 80;
  float chuckH  = 120;

  // Convert inches to pixels for stock
  float stockLenPx = stockLengthIn   * pxPerIn;
  float stockHPx   = stockDiameterIn * pxPerIn;

  // Keep stock from overflowing the workspace too crazily
  stockLenPx = min(stockLenPx, innerW * 0.75);
  stockHPx   = min(stockHPx, workspaceH * 0.6);
  
  // Chuck
  noFill();
  stroke(0);
  rect(chuckX - chuckW, centerY - chuckH / 2, chuckW, chuckH);
  line(chuckX - chuckW, centerY - 30, chuckX, centerY - 15);
  line(chuckX - chuckW, centerY + 30, chuckX, centerY + 15);
  
  // Stock (filled rectangle, inch-scaled)
  fill(180); // light gray metal
  stroke(0);
  rect(chuckX, centerY - stockHPx / 2, stockLenPx, stockHPx);
  // centerline
  // centerline (animated if spindleRPM != 0)
stroke(100);

float midLineY = centerY;  // default: no motion

  // time in seconds
  float t = millis() / 1000.0;
  // angular position: RPM [rev/min] -> rad/s -> angle
  float theta = TWO_PI * spindleRPM * t / 60.0;
  
  // how far the line moves inside the stock (fraction of radius)
  float amp = stockHPx * 0.25;   // 25% of radius up/down
  
  midLineY = centerY + amp * sin(theta);

line(chuckX, midLineY, chuckX + stockLenPx, midLineY);
  
  // ---------------- TOOL POST AND CUTTING TOOL (below stock) ----------------
    // ---------------- TOOL POST AND CUTTING TOOL (below stock) ----------------
  // Bottom of the stock
  float stockBottomY = centerY + stockHPx / 2;

  // Define tool tip position (point of the triangle)
  // toolTipXpx, toolTipYpx REFER TO THE TIP OF THE CUTTING TOOL
  toolTipXpx = chuckX + stockLenPx * 0.50;   // roughly mid-stock along Z
  toolTipYpx = stockBottomY + 10;            // just below the part

  // --- Orange cutting tip (triangle) pointing upward ---
  float tipW = 12;   // width of the base of the triangle
  float tipH = 10;   // height of the triangle

  fill(255, 140, 0);   // orange tip
  stroke(0);
  triangle(
    toolTipXpx,              toolTipYpx,           // TIP
    toolTipXpx - tipW/2,     toolTipYpx + tipH,    // left base point
    toolTipXpx + tipW/2,     toolTipYpx + tipH     // right base point
  );

  // --- Vertical shank below the tip ---
  float toolShankW = 12;
  float toolShankH = 60;

  float toolShankX = toolTipXpx - toolShankW / 2;
  float toolShankY = toolTipYpx + tipH;       // starts right under the triangle base

  fill(180);   // gray metal shank
  stroke(0);
  rect(toolShankX, toolShankY, toolShankW, toolShankH);

  // --- Tool post block further below the shank ---
  float postW = 60;
  float postH = 60;
  float postCenterX = toolTipXpx;
  float postCenterY = toolShankY + toolShankH + postH/2 - 10;  // small overlap up

  fill(255);
  stroke(0);
  rect(postCenterX - postW/2, postCenterY - postH/2, postW, postH);


  // ----- Compute tool X/Z positions in inches from toolTip and geometry -----
  // Z: distance along the stock from the chuck face
  rawZIn = (toolTipXpx - chuckX) / pxPerIn;

  // X: radial position relative to stock centerline (simple mapping for now)
  rawXIn = (centerY - toolTipYpx) / pxPerIn;

  // Apply zero offsets for displayed readout
  xPosIn = rawXIn - xZeroOffsetIn;
  zPosIn = rawZIn - zZeroOffsetIn;



// ---------------- BORING BAR TO THE RIGHT OF THE STOCK ----------------

// Right face of the stock
float stockRightX = chuckX + stockLenPx;

// Tool post position (to the right of stock)
float boringPostW = 40;
float boringPostH = 80;
float boringPostX = stockRightX + 80;        // horizontal offset from stock
float boringPostY = centerY + 0;            // slightly below centerline

// Draw tool post (vertical block)
stroke(0);
fill(255);
rect(boringPostX - boringPostW/2,
     boringPostY - boringPostH/2,
     boringPostW,
     boringPostH);

// Boring bar (horizontal bar from post toward stock)
float barH = 10;
float barY = centerY;                        // align with stock center
float barLeftX  = stockRightX + 30;           // just off the stock face
float barRightX = boringPostX - boringPostW/2;  // left edge of post
float barLen = barRightX - barLeftX;

fill(180);  // gray metal
stroke(0);
rect(barLeftX, barY - barH/2, barLen, barH);

// Orange cutting tip at the bar's left end, pointing into the stock
float tipSize = 10;

fill(255, 140, 0);   // orange
stroke(0);
triangle(
  barLeftX  - tipSize ,            barY,                 // base at bar front
  barLeftX ,  barY + tipSize/2,     // top point inside stock
  barLeftX,  barY - tipSize/2      // bottom point inside stock
);

}

// ----------------------------------------------------
// BUTTON DRAW HELPERS (hover + selected color logic)
// ----------------------------------------------------
void drawSubPanelTitle(float x, float y, String title) {
  fill(0);
  textSize(14);
  text(title, x, y);
}

void drawPillButton(float x, float centerY, String label, boolean selected) {
  float w = 180;
  float h = 24;
  float y = centerY - h / 2;
  
  boolean hover = overRect(x, y, w, h);
  
  if (selected) {
    fill(0, 200, 0);           // green when selected
  } else if (hover) {
    fill(220);                 // light gray when hovering
  } else {
    fill(255);                 // white default
  }
  
  stroke(0);
  rect(x, y, w, h, 12);
  
  fill(0);
  textSize(12);
  text(label, x + 10, centerY);
}

void drawOutlinedButton(float x, float centerY, String label, boolean selected) {
  float w = 180;
  float h = 22;
  float y = centerY - h / 2;
  
  boolean hover = overRect(x, y, w, h);
  
  if (selected) {
    fill(0, 200, 0);          // green when selected
  } else if (hover) {
    fill(220);                // light gray on hover
  } else {
    noFill();
  }
  
  stroke(0);
  rect(x, y, w, h, 6);
  
  fill(0);
  textSize(12);
  text(label, x + 8, centerY);
}

void drawSubPanelBox(float x, float y, float w, float h, String title) {
  fill(255);
  stroke(0);
  rect(x, y, w, h);
  fill(0);
  textSize(14);
  text(title, x + 8, y + 18);
}

// Simple line with arrowhead
void arrow(float x1, float y1, float x2, float y2) {
  line(x1, y1, x2, y2);
  float angle = atan2(y2 - y1, x2 - x1);
  float len = 20;
  float a1 = angle + radians(150);
  float a2 = angle - radians(150);
  line(x2, y2, x2 - len * cos(a1), x2 - len * sin(a1));
  line(x2, y2, x2 - len * cos(a2), x2 - len * sin(a2));
}

// Hit-test helper
boolean overRect(float x, float y, float w, float h) {
  return (mouseX >= x && mouseX <= x + w &&
          mouseY >= y && mouseY <= y + h);
}

// ----------------------------------------------------
// MOUSE INTERACTION: toggle selected state on click
// ----------------------------------------------------
void mousePressed() {
  float x = 0;
  float y = headerH;
  float innerX = x + padding;
  float innerY = y + padding;

  // ---- Positions mirror drawLeftPanel() logic ----
  // Training Scenario
  innerY += 25;  // Facing center Y
  if (overRect(innerX, innerY - 12, 180, 24)) {
    facingSelected  = true;
    turnDiaSelected = false;
    boringSelected  = false;
    customSelected  = false;
  }
  innerY += 30;  // Turn to Diameter
  if (overRect(innerX, innerY - 12, 180, 24)) {
    facingSelected  = false;
    turnDiaSelected = true;
    boringSelected  = false;
    customSelected  = false;
  }
  innerY += 30;  // Boring
  if (overRect(innerX, innerY - 12, 180, 24)) {
    facingSelected  = false;
    turnDiaSelected = false;
    boringSelected  = true;
    customSelected  = false;
  }
  innerY += 30;  // (no custom button drawn, but keep logic harmless)
  if (overRect(innerX, innerY - 12, 180, 24)) {
    facingSelected  = false;
    turnDiaSelected = false;
    boringSelected  = false;
    customSelected  = true;
  }
  
  // Skill Level
    // Skill Level (mutually exclusive)
  innerY += 45;  // title

  // Beginner
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    beginnerSelected     = true;
    intermediateSelected = false;
    advancedSelected     = false;
  }

  // Intermediate
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    beginnerSelected     = false;
    intermediateSelected = true;
    advancedSelected     = false;
  }

  // Advanced
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    beginnerSelected     = false;
    intermediateSelected = false;
    advancedSelected     = true;
  }

    // Controls
  innerY += 45;  // title

  // Reset Workpiece (momentary)
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    resetFlashStart = millis();
    // You can later add real "reset" behavior here if desired
  }

  // Zero X (momentary, zero readout only)
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    zeroXFlashStart = millis();
    xZeroOffsetIn = rawXIn;   // so xPosIn = rawXIn - xZeroOffsetIn = 0
  }

  // Zero Z (momentary, zero readout only)
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    zeroZFlashStart = millis();
    zZeroOffsetIn = rawZIn;   // so zPosIn = rawZIn - zZeroOffsetIn = 0
  }

  // Show Toolpath (true toggle)
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    pathSelected = !pathSelected;
  }


  
  // ------------------------------------------------
  // Cutting parameter field selection (right panel)
  // ------------------------------------------------
  // Click in any of the three boxes to activate that field
  if (overRect(rpmBoxX, rpmBoxY, rpmBoxW, rpmBoxH)) {
    activeField = 1;
  } else if (overRect(feedBoxX, feedBoxY, feedBoxW, feedBoxH)) {
    activeField = 2;
  } else if (overRect(docBoxX, docBoxY, docBoxW, docBoxH)) {
    activeField = 3;
  } else {
    // click elsewhere -> deselect
    activeField = 0;
  }

}

void keyPressed() {
  // Only edit if a field is active
  if (activeField == 0) return;

  // Handle backspace
  if (key == BACKSPACE) {
    if (activeField == 1 && spindleStr.length() > 0) {
      spindleStr = spindleStr.substring(0, spindleStr.length() - 1);
    } else if (activeField == 2 && feedStr.length() > 0) {
      feedStr = feedStr.substring(0, feedStr.length() - 1);
    } else if (activeField == 3 && docStr.length() > 0) {
      docStr = docStr.substring(0, docStr.length() - 1);
    }
    return;
  }

  // Confirm entry with Enter / Return -> parse to floats
  if (key == ENTER || key == RETURN) {
    if (activeField == 1) {
      if (spindleStr.length() > 0) spindleRPM = float(spindleStr);
    } else if (activeField == 2) {
      if (feedStr.length() > 0) feedRate = float(feedStr);
    } else if (activeField == 3) {
      if (docStr.length() > 0) depthCut = float(docStr);
    }
    return;
  }

  // Accept only digits, decimal point, and a minus sign (if you want negatives)
  boolean isDigit = (key >= '0' && key <= '9');
  boolean isDot   = (key == '.');

  if (!isDigit && !isDot) {
    return; // ignore other keys
  }

  if (activeField == 1) {
    spindleStr += key;
  } else if (activeField == 2) {
    feedStr += key;
  } else if (activeField == 3) {
    docStr += key;
  }
}
