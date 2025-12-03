// ==================== HapticLatheGUI.pde ====================
// Main sketch file: window, layout, GUI drawing, and event handling.
// Uses LatheState, ToolState, and Bridge classes defined in other tabs.

// ===== WINDOW DIMENSIONS =====
int W = 1280;
int H = 720;
int headerH    = 60;
int footerH    = 60;
int leftPanelW = 220;
int rightPanelW = 330;
int padding    = 10;

// ===== COLORS =====
int bgColor;
int panelStroke;
int panelFill;
int headerFill;
int footerFill;
int accentFill;

// ===== GLOBAL STATE OBJECTS =====
LatheState lathe;
ToolState tool;
Bridge bridge;

// ===== BUTTON / FIELD STATE =====
// Controls
boolean pathSelected = false;

// momentary flash timing
int flashDuration    = 200;   // ms
int resetFlashStart  = -1000;
int zeroXFlashStart  = -1000;
int zeroZFlashStart  = -1000;

// cutting parameter text fields
String spindleStr = "0";
String feedStr    = "0.000";
String docStr     = "0.000";

// which field is active? 0 = none, 1 = spindle, 2 = feed, 3 = doc
int activeField = 0;

// bounding boxes for text-click
float rpmBoxX, rpmBoxY, rpmBoxW, rpmBoxH;
float feedBoxX, feedBoxY, feedBoxW, feedBoxH;
float docBoxX, docBoxY, docBoxW, docBoxH;

// Axis selection (X = radial, Z = axial)
String activeAxis = "Z";        // default axial
boolean usePhysicalInput = true;

// temp storage for parameter floats
float spindleRPM = 0;
float feedRate   = 0;
float depthCut   = 0;

// Axis button bounds (in Drawing / Tolerances view)
float axisXBtnX, axisXBtnY, axisXBtnW, axisXBtnH;
float axisZBtnX, axisZBtnY, axisZBtnW, axisZBtnH;

// ===== SETUP =====
void setup() {
  size(1280, 720);
  smooth();
  textAlign(LEFT, CENTER);
  textFont(createFont("Arial", 14));

  // colors
  bgColor     = color(245);
  panelStroke = color(0);
  panelFill   = color(255);
  headerFill  = color(230);
  footerFill  = color(230);
  accentFill  = color(240);

  // create state objects
  lathe = new LatheState();
  tool  = new ToolState();
  bridge = new Bridge();

  // initialize bridge file paths
  String tempDir = System.getProperty("java.io.tmpdir");
  bridge.initPaths(tempDir + "/lathe_bridge_status.json",
                   tempDir + "/lathe_gui_commands.json");

  // initial connection check
  bridge.checkConnection();

  // initial facing + beginner by default
  lathe.facingSelected   = true;
  lathe.beginnerSelected = true;

  // ask bridge for status initially
  if (bridge.connected) {
    bridge.sendRaw("{\"type\":\"status_request\"}");
  }
}

// ===== MAIN DRAW LOOP =====
void draw() {
  background(bgColor);

  // periodically check bridge connection
  if (frameCount % 60 == 0) {   // about once per second @60fps
    bridge.checkConnection();
  }

  // receive messages from bridge
  bridge.pollStatus(lathe, tool);

  // update lathe scenario dimensions from selection
  lathe.updateStockFromScenario();

  // update tool position (hook for future; geometry is set in drawMainView)
  tool.updatePosition(lathe, bridge, usePhysicalInput, activeAxis);

  // main GUI
  drawHeader();
  drawFooter();
  drawLeftPanel();
  drawMainView();   // computes geometry, X/Z, and calls tool.updateCollision()
  drawRightPanel(); // uses updated tool state

  // periodically request status from bridge
  if (bridge.connected && frameCount % 30 == 0) {
    bridge.sendRaw("{\"type\":\"status_request\"}");
  }
}

// ==================== HEADER ====================
void drawHeader() {
  fill(headerFill);
  stroke(panelStroke);
  rect(0, 0, W, headerH);
  
  fill(0);
  textSize(22);
  text("Haptic Lathe Simulator", padding, headerH / 2);

  // Simple Lathe Mode indicator
  float toggleW = 160;
  float toggleH = 30;
  float toggleX = W - toggleW - padding - 50;
  float toggleY = headerH / 2 - toggleH / 2;
  
  fill(255);
  stroke(0);
  rect(toggleX, toggleY, toggleW, toggleH, 8);
  fill(0, 200, 0);
  textSize(13);
  textAlign(CENTER, CENTER);
  text("Lathe Mode", toggleX + toggleW / 2, toggleY + toggleH / 2);

  textAlign(LEFT, CENTER);
}

// ==================== FOOTER ====================
void drawFooter() {
  float y = H - footerH;
  fill(footerFill);
  stroke(panelStroke);
  rect(0, y, W, footerH);
  
  fill(0);
  textSize(14);

  // LEFT: consolidated motor / bridge status
  String status = "Status: ";
  if (bridge.connected) {
    status += "Connected • ";
    status += (usePhysicalInput ? "Physical Input" : "Mouse Input");
    if (millis() - bridge.lastHeartbeat > bridge.heartbeatInterval) {
      status += " • CONNECTION LOST";
    } else {
      status += " • Handle: " + nf(bridge.handlePosition, 0, 1) + "°";
    }
  } else {
    status += "Disconnected • Mouse Input Only • Simulation Mode";
  }
  text(status, padding, y + footerH / 2);

  // RIGHT: encoder position only, in same visual style
  String encText = "Encoder: " + nf(bridge.handlePosition, 0, 1) + "°";
  float tw = textWidth(encText);
  text(encText, W - padding - tw, y + footerH / 2);
}

// ==================== LEFT PANEL ====================
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
  drawPillButton(innerX, innerY, "Facing", lathe.facingSelected);
  innerY += 30;
  drawPillButton(innerX, innerY, "Turn to Diameter", lathe.turnDiaSelected);
  innerY += 30;
  drawPillButton(innerX, innerY, "Boring", lathe.boringSelected);
  innerY += 30;
  
  // ----- Skill Level -----
  innerY += 45;
  drawSubPanelTitle(innerX, innerY, "Skill Level");
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Beginner",     lathe.beginnerSelected);
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Intermediate", lathe.intermediateSelected);
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Advanced",     lathe.advancedSelected);
  
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

  // Show Toolpath (toggle)
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Show Toolpath", pathSelected);
}

// ==================== RIGHT PANEL ====================
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
  
  // ----- Live readouts -----
  drawSubPanelBox(innerX, innerY, sectionW, 140, "Live Readouts");
  float lineY = innerY + 40;
  float lineH = 22;
  fill(0);
  textSize(14);
  text("X Position:   " + nfp(tool.xPosIn, 1, 3) + " in", innerX + 10, lineY); lineY += lineH;
  text("Z Position:   " + nfp(tool.zPosIn, 1, 3) + " in", innerX + 10, lineY); lineY += lineH;
  text("Tool Load Fx: " + (tool.collision ? nf(tool.collisionForce, 1, 1) : "0.0") + " N", innerX + 10, lineY); lineY += lineH;
  text("Tool Load Fz: 0.0 N", innerX + 10, lineY); lineY += lineH;
  
  innerY += 150;
  
  // ----- Cutting parameters (editable) -----
  drawSubPanelBox(innerX, innerY, sectionW, 170, "Cutting Parameters");
  lineY = innerY + 40;
  lineH = 22;
  textSize(14);
  
  // Spindle Speed field
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
  
  // Feed Rate field
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

  // Depth of Cut field
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

  // Material & coolant
  fill(0);
  text("Material: Mild Steel", innerX + 10, lineY); lineY += lineH;
  text("Coolant: On / Off",    innerX + 10, lineY);
  
  innerY += 190;
  
  // ----- Tolerance summary -----
  drawSubPanelBox(innerX, innerY, sectionW, 120, "Tolerance Summary");
  lineY = innerY + 40;

  String tolStr2 = lathe.getToleranceString();
  String scenario = lathe.getScenario();
  String currentOpStr;
  String targetStr;
  String currentStr;

  if (scenario.equals("facing")) {
    currentOpStr = "Facing to overall length";
    targetStr    = "Target: L = 4.000 " + tolStr2;
    currentStr   = "Current: L = 4.012";
  } else if (scenario.equals("turn")) {
    currentOpStr = "Turn shoulder to Ø 1.000 in";
    targetStr    = "Target: Ø 1.000 " + tolStr2;
    currentStr   = "Current: Ø 1.012";
  } else if (scenario.equals("boring")) {
    currentOpStr = "Bore ID to Ø 1.000 in";
    targetStr    = "Target: Ø 1.000 " + tolStr2;
    currentStr   = "Current: Ø 1.006";
  } else {
    currentOpStr = "User-defined operation";
    targetStr    = "Target: per setup (" + tolStr2 + ")";
    currentStr   = "Current: Measurement TBD";
  }

  textSize(12);
  text(currentOpStr, innerX + 10, lineY); lineY += lineH;
  text(targetStr,   innerX + 10, lineY); lineY += lineH;
  text(currentStr,  innerX + 10, lineY);
}

// ==================== MAIN VIEW ====================
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

  // ---------- Drawing / Tolerances View ----------
  String stockLine;
  String opLine;
  String datumLine;

  String tolStr   = lathe.getToleranceString();
  String scenario = lathe.getScenario();

  if (scenario.equals("facing")) {
    stockLine = "• Stock: Ø " + nf(lathe.stockDiameterIn, 1, 2) + " in x " +
                nf(lathe.stockLengthIn,   1, 2) + " in";
    opLine    = "• Operation: Facing to overall length 4.000 " + tolStr;
    datumLine = "• Datum: Chuck face (Z = 0.000 in)";
  } else if (scenario.equals("turn")) {
    stockLine = "• Stock: Ø " + nf(lathe.stockDiameterIn, 1, 2) + " in x " +
                nf(lathe.stockLengthIn,   1, 2) + " in";
    opLine    = "• Operation: Turn shoulder to Ø 1.000 " + tolStr;
    datumLine = "• Datum: Shoulder location from Z = 0.000 in";
  } else if (scenario.equals("boring")) {
    stockLine = "• Stock: Ø " + nf(lathe.stockDiameterIn, 1, 2) + " in x " +
                nf(lathe.stockLengthIn,   1, 2) + " in (pre-drilled)";
    opLine    = "• Operation: Bore ID to Ø 1.000 " + tolStr;
    datumLine = "• Datum: Bore start at Z = 0.000 in";
  } else {
    stockLine = "• Stock: Ø " + nf(lathe.stockDiameterIn, 1, 2) + " in x " +
                nf(lathe.stockLengthIn,   1, 2) + " in";
    opLine    = "• Operation: User-defined (custom)";
    datumLine = "• Datum: Defined per setup";
  }

  float drawingH = 160;
  fill(accentFill);
  rect(innerX, innerY, innerW, drawingH);
  fill(0);
  textSize(16);
  text("Drawing / Tolerances View", innerX + 10, innerY + 20);
  textSize(12);
  text(stockLine + "\n" + opLine + "\n" + datumLine,
       innerX + 10, innerY + 55);

  // ---------- Active Axis buttons (top-right, replacing wireframe) ----------
  float axisAreaX = innerX + innerW - 260;
  float axisAreaY = innerY + 20;
  float axisAreaW = 240;
  float axisAreaH = drawingH - 40;

  fill(255);
  stroke(0);
  rect(axisAreaX, axisAreaY, axisAreaW, axisAreaH);
  fill(0);
  textSize(12);
  text("Active Axis", axisAreaX + 10, axisAreaY + 15);

  float btnW = (axisAreaW - 30) / 2.0;
  float btnH = 24;
  float btnY = axisAreaY + 40;
  float btnX1 = axisAreaX + 10;
  float btnX2 = btnX1 + btnW + 10;

  // store button bounds for mousePressed
  axisXBtnX = btnX1;
  axisXBtnY = btnY - btnH / 2;
  axisXBtnW = btnW;
  axisXBtnH = btnH;

  axisZBtnX = btnX2;
  axisZBtnY = btnY - btnH / 2;
  axisZBtnW = btnW;
  axisZBtnH = btnH;

  // X button
  boolean xActive = activeAxis.equals("X");
  fill(xActive ? color(100, 200, 100) : color(230));
  stroke(0);
  rect(axisXBtnX, axisXBtnY, axisXBtnW, axisXBtnH, 8);
  fill(0);
  textAlign(CENTER, CENTER);
  text("X (Radial)", axisXBtnX + axisXBtnW / 2, axisXBtnY + axisXBtnH / 2);

  // Z button
  boolean zActive = activeAxis.equals("Z");
  fill(zActive ? color(100, 200, 100) : color(230));
  stroke(0);
  rect(axisZBtnX, axisZBtnY, axisZBtnW, axisZBtnH, 8);
  fill(0);
  text("Z (Axial)", axisZBtnX + axisZBtnW / 2, axisZBtnY + axisZBtnH / 2);
  textAlign(LEFT, CENTER);

  // ---------- Workspace ----------
  float workspaceY = innerY + drawingH + padding;
  float workspaceH = innerH - drawingH - padding;
  fill(255);
  rect(innerX, workspaceY, innerW, workspaceH);
  
  fill(0);
  textSize(16);
  text("Virtual Lathe Workspace", innerX + 10, workspaceY + 20);
  
  // geometry
  float centerY = workspaceY + workspaceH * 0.40;
  float chuckX  = innerX + 100;
  float chuckW  = 80;
  float chuckH  = 120;

  float stockLenPx = lathe.stockLengthIn   * lathe.pxPerIn;
  float stockHPx   = lathe.stockDiameterIn * lathe.pxPerIn;
  stockLenPx = min(stockLenPx, innerW * 0.75);
  stockHPx   = min(stockHPx, workspaceH * 0.6);

  float stockRightX   = chuckX + stockLenPx;
  float stockTopY     = centerY - stockHPx / 2;
  float stockBottomY  = centerY + stockHPx / 2;
  float stockRadiusPx = stockHPx / 2.0;
  
  // Chuck
  noFill();
  stroke(0);
  rect(chuckX - chuckW, centerY - chuckH / 2, chuckW, chuckH);
  line(chuckX - chuckW, centerY - 30, chuckX, centerY - 15);
  line(chuckX - chuckW, centerY + 30, chuckX, centerY + 15);
  
  // Stock
  fill(180);
  stroke(0);
  // Stock
  fill(180);
  stroke(0);
  
  if (lathe.radiusProfileIn != null) {
    beginShape();
    // Top edge (left to right)
    for (int i = 0; i < lathe.profileSamples; i++) {
        float z = map(i, 0, lathe.profileSamples-1, 0, lathe.stockLengthIn);
        float r = lathe.radiusProfileIn[i];
        float pxX = chuckX + z * lathe.pxPerIn;
        float pxY = centerY - r * lathe.pxPerIn;
        vertex(pxX, pxY);
    }
    
    // Bottom edge (right to left)
    for (int i = lathe.profileSamples - 1; i >= 0; i--) {
        float z = map(i, 0, lathe.profileSamples-1, 0, lathe.stockLengthIn);
        float r = lathe.radiusProfileIn[i];
        float pxX = chuckX + z * lathe.pxPerIn;
        float pxY = centerY + r * lathe.pxPerIn;
        vertex(pxX, pxY);
    }
    
    endShape(CLOSE);
  } else {
    rect(chuckX, stockTopY, stockLenPx, stockHPx);
  }

  // Animated centerline (based on spindle RPM)
  stroke(100);
  float midLineY = centerY;
  float t = millis() / 1000.0;
  float theta = TWO_PI * lathe.spindleRPM * t / 60.0;
  float amp = stockHPx * 0.25;
  midLineY = centerY + amp * sin(theta);
  line(chuckX, midLineY, chuckX + stockLenPx, midLineY);

  // ----- CUTTING TOOL -----
  if (usePhysicalInput && bridge.connected) {
    float movementRange = 360.0;
    float movementScale = 1.0;

    if (activeAxis.equals("Z")) {
      float zMovement = map(bridge.handlePosition,
                            -movementRange/2, movementRange/2,
                            -stockLenPx*0.5, stockLenPx*0.5);
      tool.toolTipXpx = chuckX + stockLenPx * 0.50 + zMovement * movementScale;
      tool.toolTipYpx = centerY + stockRadiusPx + 20;
    } else {
      float xMovement = map(bridge.handlePosition,
                            -movementRange/2, movementRange/2,
                            -stockHPx*0.4, stockHPx*0.4);
      tool.toolTipXpx = chuckX + stockLenPx * 0.50;
      tool.toolTipYpx = centerY - xMovement * movementScale;
    }
  } else {
    // default "air cutting" position
    tool.toolTipXpx = chuckX + stockLenPx * 0.50;
    tool.toolTipYpx = centerY + stockRadiusPx + 20;
  }

  // Draw tool
  float tipW = 12;
  float tipH = 10;
  fill(255, 140, 0);
  stroke(0);
  
  // if collision, make the insert red
  if (tool.collision) {
    fill(255, 0, 0);          // red on contact
  } else {
    fill(255, 140, 0);        // orange otherwise
  }
  
  triangle(
    tool.toolTipXpx,              tool.toolTipYpx,
    tool.toolTipXpx - tipW/2,     tool.toolTipYpx + tipH,
    tool.toolTipXpx + tipW/2,     tool.toolTipYpx + tipH
  );

  float toolShankW = 12;
  float toolShankH = 60;
  float toolShankX = tool.toolTipXpx - toolShankW / 2;
  float toolShankY = tool.toolTipYpx + tipH;

  fill(180);
  stroke(0);
  rect(toolShankX, toolShankY, toolShankW, toolShankH);

  float postW = 60;
  float postH = 60;
  float postCenterX = tool.toolTipXpx;
  float postCenterY = toolShankY + toolShankH + postH/2 - 10;

  fill(255);
  stroke(0);
  rect(postCenterX - postW/2, postCenterY - postH/2, postW, postH);

  // ----- Update tool's inch coordinates (raw & zeroed) -----
  tool.rawZIn = (tool.toolTipXpx - chuckX) / lathe.pxPerIn;
  tool.rawXIn = (centerY - tool.toolTipYpx) / lathe.pxPerIn;
  tool.xPosIn = tool.rawXIn - tool.xZeroOffsetIn;
  tool.zPosIn = tool.rawZIn - tool.zZeroOffsetIn;

  // ----- Collision detection and haptics (ToolState) -----
  tool.updateCollision(lathe, bridge, chuckX, stockRightX, centerY, stockRadiusPx);

  
  // Boring bar only in boring mode
  if (scenario.equals("boring")) {
    float boringPostW = 40;
    float boringPostH = 80;
    float boringPostX = stockRightX + 80;
    float boringPostY = centerY;

    stroke(0);
    fill(255);
    rect(boringPostX - boringPostW/2,
         boringPostY - boringPostH/2,
         boringPostW,
         boringPostH);

    float barH = 10;
    float barY = centerY;
    float barLeftX  = stockRightX + 30;
    float barRightX = boringPostX - boringPostW/2;
    float barLen = barRightX - barLeftX;

    fill(180);
    stroke(0);
    rect(barLeftX, barY - barH/2, barLen, barH);

    float tipSize = 10;
    fill(255, 140, 0);
    stroke(0);
    triangle(
      barLeftX - tipSize,  barY,
      barLeftX,            barY + tipSize/2,
      barLeftX,            barY - tipSize/2
    );
  }
}

// ==================== GUI HELPERS ====================
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
    fill(0, 200, 0);
  } else if (hover) {
    fill(220);
  } else {
    fill(255);
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
    fill(0, 200, 0);
  } else if (hover) {
    fill(220);
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

boolean overRect(float x, float y, float w, float h) {
  return (mouseX >= x && mouseX <= x + w &&
          mouseY >= y && mouseY <= y + h);
}

// ==================== MOUSE INTERACTION ====================
void mousePressed() {
  float x = 0;
  float y = headerH;
  float innerX = x + padding;
  float innerY = y + padding;

  // parameter fields first
  if (overRect(rpmBoxX, rpmBoxY, rpmBoxW, rpmBoxH)) {
    activeField = 1;  return;
  } else if (overRect(feedBoxX, feedBoxY, feedBoxW, feedBoxH)) {
    activeField = 2;  return;
  } else if (overRect(docBoxX, docBoxY, docBoxW, docBoxH)) {
    activeField = 3;  return;
  } else {
    activeField = 0;
  }

  // Training Scenario
  innerY += 25;  // Facing
  if (overRect(innerX, innerY - 12, 180, 24)) {
    lathe.selectScenario("facing");
    bridge.sendModeChange("facing", lathe.getSkillLevel());
  }
  innerY += 30;  // Turn to Diameter
  if (overRect(innerX, innerY - 12, 180, 24)) {
    lathe.selectScenario("turn");
    bridge.sendModeChange("turning", lathe.getSkillLevel());
  }
  innerY += 30;  // Boring
  if (overRect(innerX, innerY - 12, 180, 24)) {
    lathe.selectScenario("boring");
    bridge.sendModeChange("boring", lathe.getSkillLevel());
  }
  innerY += 30;

  // Skill Level (mutually exclusive)
  innerY += 45;  // title

  innerY += 25;  // Beginner
  if (overRect(innerX, innerY - 11, 180, 22)) {
    lathe.selectSkill("beginner");
  }

  innerY += 25;  // Intermediate
  if (overRect(innerX, innerY - 11, 180, 22)) {
    lathe.selectSkill("intermediate");
  }

  innerY += 25;  // Advanced
  if (overRect(innerX, innerY - 11, 180, 22)) {
    lathe.selectSkill("advanced");
  }

  // Controls
  innerY += 45;  // title

  // Reset Workpiece
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    resetFlashStart = millis();
    bridge.sendReset();
    lathe.initProfile();
  }

  // Zero X
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    zeroXFlashStart = millis();
    tool.xZeroOffsetIn = tool.rawXIn;
    bridge.sendZero("x");
  }

  // Zero Z
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    zeroZFlashStart = millis();
    tool.zZeroOffsetIn = tool.rawZIn;
    bridge.sendZero("z");
  }

  // Show Toolpath
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    pathSelected = !pathSelected;
  }

  // ----- Active Axis buttons (in drawing view) -----
  if (overRect(axisXBtnX, axisXBtnY, axisXBtnW, axisXBtnH)) {
    activeAxis = "X";
    bridge.sendAxisSelect("X");
  } else if (overRect(axisZBtnX, axisZBtnY, axisZBtnW, axisZBtnH)) {
    activeAxis = "Z";
    bridge.sendAxisSelect("Z");
  }
}

// ==================== KEYBOARD INTERACTION ====================
void keyPressed() {
  // field editing
  if (activeField != 0) {
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

    if (key == ENTER || key == RETURN) {
      if (activeField == 1) {
        if (spindleStr.length() > 0) {
          spindleRPM = float(spindleStr);
          lathe.spindleRPM = spindleRPM;
          bridge.updateCuttingParameters(lathe.spindleRPM, lathe.feedRate);
        }
      } else if (activeField == 2) {
        if (feedStr.length() > 0) {
          feedRate = float(feedStr);
          lathe.feedRate = feedRate;
          bridge.updateCuttingParameters(lathe.spindleRPM, lathe.feedRate);
        }
      } else if (activeField == 3) {
        if (docStr.length() > 0) {
          depthCut = float(docStr);
          lathe.depthCut = depthCut;
        }
      }
      return;
    }

    boolean isDigit = (key >= '0' && key <= '9');
    boolean isDot   = (key == '.');
    if (!isDigit && !isDot) return;

    if (activeField == 1) {
      spindleStr += key;
    } else if (activeField == 2) {
      feedStr += key;
    } else if (activeField == 3) {
      docStr += key;
    }
    return;
  }

  // emergency stop on spacebar
  if (key == ' ') {
    bridge.sendEmergencyStop();
  }

  // toggle physical input
  if (key == 'p' || key == 'P') {
    usePhysicalInput = !usePhysicalInput;
  }
}
