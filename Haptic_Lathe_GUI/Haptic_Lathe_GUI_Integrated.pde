import processing.net.*;

// Haptic Lathe Simulator GUI - Integrated with Physical Motor
// - TCP Socket communication with Python bridge
// - Handle wheel position input from motor encoder
// - Real-time haptic feedback

// TCP Communication
Client bridgeClient;
String bridgeHost = "127.0.0.1";
int bridgePort = 5005;
boolean bridgeConnected = false;
int lastReconnectAttempt = 0;
int reconnectInterval = 2000;

JSONObject lastStatus;
float physicalHandlePosition = 0.0;  // degrees from motor encoder
boolean usePhysicalInput = true;     // toggle between mouse and physical input
long lastHeartbeat = 0;
int heartbeatInterval = 1000;        // 1 second timeout

// Original GUI variables
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

// Material Removal State
float[] stockProfile; // Array storing radius (in pixels) at each Z-pixel
int stockProfileLen;  // Length of the profile array

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
boolean zeroXSelected        = false;
boolean zeroZSelected        = false;
boolean pathSelected         = false;

// Axis selection (X = radial, Z = axial)
String activeAxis = "Z";  // Default to Z-axis (axial movement)

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

// Collision detection
boolean toolCollision = false;
float collisionForce = 0.0;  // Force magnitude when collision detected
float currentForce = 0.0;    // Current force being applied [N]
float lastSentForce = 0.0;   // Track last sent force to avoid flooding

// Relative Positioning State
float currentToolX = 0;      // Current X position (pixels)
float currentToolZ = 0;      // Current Z position (pixels)
float lastHandlePosition = 0; // Last read encoder position
boolean firstBridgeUpdate = true; // Flag to sync handle

// Previous tool position for interpolation
float prevToolTipXpx = 0;
float prevToolTipYpx = 0;
boolean firstFrame = true;

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

  // Initialize TCP Connection
  connectToBridge();
  
  // Initialize Tool Position (Safe Home)
  // Center of workspace X, below stock Y
  float centerY = (headerH + padding + 160 + padding) + (H - headerH - footerH - 160 - 2*padding) * 0.40;
  float chuckX  = leftPanelW + padding + 100;
  float stockLenPx = stockLengthIn * pxPerIn;
  float stockHPx   = stockDiameterIn * pxPerIn;
  float stockRadiusPx = stockHPx / 2.0;
  
  // Start Z at center of stock
  currentToolZ = chuckX + stockLenPx * 0.50;
  
  // Start X well outside the stock (below it)
  // Start X well outside the stock (below it)
  currentToolX = centerY + stockRadiusPx + 40; // 40px clearance
  
  // Initialize Stock Profile
  initStockProfile();
}

void initStockProfile() {
  stockProfileLen = int(stockLengthIn * pxPerIn) + 100; // Extra buffer
  stockProfile = new float[stockProfileLen];
  float radiusPx = (stockDiameterIn * pxPerIn) / 2.0;
  for (int i = 0; i < stockProfileLen; i++) {
    stockProfile[i] = radiusPx;
  }
}

void connectToBridge() {
  try {
    bridgeClient = new Client(this, bridgeHost, bridgePort);
    if (bridgeClient.active()) {
      bridgeConnected = true;
      println("✅ Connected to Bridge via TCP");
      // Send initial status request
      sendToBridge("{\"type\":\"status_request\"}");
    } else {
      bridgeConnected = false;
      println("⚠️ Could not connect to Bridge");
    }
  } catch (Exception e) {
    println("❌ Connection error: " + e);
    bridgeConnected = false;
  }
}

// Check if Python bridge is connected
void checkBridgeConnection() {
  if (bridgeClient != null && bridgeClient.active()) {
    bridgeConnected = true;
  } else {
    bridgeConnected = false;
    // Auto-reconnect
    if (millis() - lastReconnectAttempt > reconnectInterval) {
      println("🔄 Attempting to reconnect...");
      connectToBridge();
      lastReconnectAttempt = millis();
    }
  }
}

// Send JSON command to bridge via TCP
void sendToBridge(String jsonString) {
  if (bridgeConnected) {
    try {
      bridgeClient.write(jsonString + "\n");
    } catch (Exception e) {
      println("Error sending to bridge: " + e);
      bridgeConnected = false;
    }
  }
}

// Read incoming data from bridge via TCP
void checkBridgeMessages() {
  if (bridgeConnected) {
    try {
      // Burst read: process ALL available messages to drain the buffer
      // This prevents lag if messages arrive faster than frame rate
      while (bridgeClient.available() > 0) {
        String data = bridgeClient.readStringUntil('\n');
        if (data != null) {
          data = trim(data);
          JSONObject json = parseJSONObject(data);
          if (json != null) {
            processBridgeMessage(json);
          }
        }
      }
    } catch (Exception e) {
      println("Error reading bridge data: " + e);
    }
  }
}

void processBridgeMessage(JSONObject msg) {
  String msgType = msg.getString("type", "");

  if (msgType.equals("status_update")) {
    physicalHandlePosition = msg.getFloat("handle_wheel_position", 0.0);
    lastHeartbeat = millis();

    // Update GUI display values
    // String mode = msg.getString("mode", "manual");  // Reserved for future use
    // String skill = msg.getString("skill_level", "beginner");  // Reserved for future use
    boolean eStop = msg.getBoolean("emergency_stop", false);

    // Update status display
    if (eStop) {
      // Change footer to show emergency stop
      // This would require modifying the footer drawing function
    }
  }
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

  // ----- Training Scenario (REMOVED) -----
  // Replaced by intelligent cutting logic
  innerY += 25;
  // drawPillButton(innerX, innerY, "Facing", facingSelected);
  // innerY += 30;
  // drawPillButton(innerX, innerY, "Turn to Diameter", turnDiaSelected);
  // innerY += 30;
  // drawPillButton(innerX, innerY, "Boring", boringSelected);
  // innerY += 30;

  // ----- Skill Level -----
  innerY += 45;
  drawSubPanelTitle(innerX, innerY, "Skill Level");
  innerY += 25;

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
  innerY += 45;

  // Reset Workpiece (momentary)
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    resetFlashStart = millis();
  }

  // Zero X (momentary, zero readout only)
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    zeroXFlashStart = millis();
    xZeroOffsetIn = rawXIn;
  }

  // Zero Z (momentary, zero readout only)
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    zeroZFlashStart = millis();
    zZeroOffsetIn = rawZIn;
  }

  // Show Toolpath (true toggle)
  innerY += 25;
  if (overRect(innerX, innerY - 11, 180, 22)) {
    pathSelected = !pathSelected;
  }

  // Now draw the buttons (after hit testing)
  innerY = y + padding + 50;  // reset position for drawing

  // drawPillButton(innerX, innerY, "Facing", facingSelected);
  // innerY += 30;
  // drawPillButton(innerX, innerY, "Turn to Diameter", turnDiaSelected);
  // innerY += 30;
  // drawPillButton(innerX, innerY, "Boring", boringSelected);

  innerY += 75;  // Skip to skill level buttons
  drawOutlinedButton(innerX, innerY, "Beginner", beginnerSelected);
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Intermediate", intermediateSelected);
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Advanced", advancedSelected);

  innerY += 70;  // Skip to control buttons
  drawOutlinedButton(innerX, innerY, "Reset Workpiece", false);  // momentary
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Zero X", false);  // momentary
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Zero Z", false);  // momentary
  innerY += 25;
  drawOutlinedButton(innerX, innerY, "Show Toolpath", pathSelected);  // toggle
}

// Modify mousePressed() to send commands to bridge
void mousePressed() {
  // Check parameter field clicks first
  if (overRect(rpmBoxX, rpmBoxY, rpmBoxW, rpmBoxH)) {
    activeField = 1;  // spindle
    return;
  }
  if (overRect(feedBoxX, feedBoxY, feedBoxW, feedBoxH)) {
    activeField = 2;  // feed
    return;
  }
  if (overRect(docBoxX, docBoxY, docBoxW, docBoxH)) {
    activeField = 3;  // doc
    return;
  }
  
  // Click elsewhere = deactivate field
  activeField = 0;

  // Send mode changes to bridge (REMOVED SCENARIOS)
  // Now we just rely on activeAxis for haptic feedback direction
  // if (facingSelected) { ... }

  // Handle control buttons
  if (resetSelected) {
    sendToBridge("{\"type\":\"reset\"}");
    initStockProfile(); // Reset the visual stock
  }

  // Zero buttons now send to physical controller
  if (zeroXSelected) {
    sendToBridge("{\"type\":\"zero_position\",\"axis\":\"x\"}");
  }
  if (zeroZSelected) {
    sendToBridge("{\"type\":\"zero_position\",\"axis\":\"z\"}");
  }

  // Handle motor control buttons
  handleMotorControlClicks();
}

void handleMotorControlClicks() {
  // Calculate motor control panel position (same as in drawRightPanel)
  float x = W - rightPanelW;
  float y = headerH;
  float panelH = H - headerH - footerH;
  float innerX = x + padding;
  float innerY = y + padding;

  // Skip existing sections to find motor control section
  // Live readouts: 140px
  innerY += 150;
  // Cutting parameters: 170px
  innerY += 190;
  // Tolerance summary: 120px
  innerY += 130;  // Extra space for motor control section

  float btnW = (rightPanelW - 2 * padding - 30) / 3;
  float btnH = 25;
  float spacing = 8;
  float motorX = innerX + 10;
  float motorY = innerY + 35;

  // Check motor direction buttons (Row 1)
  if (overRect(motorX, motorY, btnW, btnH)) {
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"forward\"}");
    println("Motor Forward");
  } else if (overRect(motorX + btnW + spacing, motorY, btnW, btnH)) {
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"stop\"}");
    println("Motor Stop");
  } else if (overRect(motorX + 2*(btnW + spacing), motorY, btnW, btnH)) {
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"reverse\"}");
    println("Motor Reverse");
  }

  // Check speed buttons (Row 2)
  motorY += btnH + spacing;
  if (overRect(motorX, motorY, btnW, btnH)) {
    spindleRPM = 30;
    spindleStr = "30";
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"speed\",\"value\":30}");
    println("Motor Speed: Slow");
  } else if (overRect(motorX + btnW + spacing, motorY, btnW, btnH)) {
    spindleRPM = 100;
    spindleStr = "100";
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"speed\",\"value\":100}");
    println("Motor Speed: Medium");
  } else if (overRect(motorX + 2*(btnW + spacing), motorY, btnW, btnH)) {
    spindleRPM = 200;
    spindleStr = "200";
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"speed\",\"value\":200}");
    println("Motor Speed: Fast");
  }
  
  // Check axis selector buttons
  motorY += btnH + spacing + 10 + 16;  // Skip to axis selector
  float axisBtnW = (rightPanelW - 2 * padding - 30) / 2;
  float axisBtnH = 22;
  if (overRect(motorX, motorY, axisBtnW, axisBtnH)) {
    activeAxis = "X";
    sendToBridge("{\"type\":\"axis_select\",\"axis\":\"X\"}");
    println("Axis: X (Radial)");
  } else if (overRect(motorX + axisBtnW + 5, motorY, axisBtnW, axisBtnH)) {
    activeAxis = "Z";
    sendToBridge("{\"type\":\"axis_select\",\"axis\":\"Z\"}");
    println("Axis: Z (Axial)");
  }

  // Check position control buttons
  motorY += btnH + spacing + 10 + 18;  // Skip position readout
  float posBtnW = (rightPanelW - 2 * padding - 40) / 4;
  float posBtnH = 20;

  if (overRect(motorX, motorY, posBtnW, posBtnH)) {
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"position\",\"delta\":-10}");
    println("Position: -10°");
  } else if (overRect(motorX + posBtnW + 5, motorY, posBtnW, posBtnH)) {
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"position\",\"delta\":-1}");
    println("Position: -1°");
  } else if (overRect(motorX + 2*(posBtnW + 5), motorY, posBtnW, posBtnH)) {
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"position\",\"delta\":1}");
    println("Position: +1°");
  } else if (overRect(motorX + 3*(posBtnW + 5), motorY, posBtnW, posBtnH)) {
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"position\",\"delta\":10}");
    println("Position: +10°");
  }
}

// Add emergency stop key handler
void keyPressed() {
  // ... existing key handling ...

  // Toggle Axis on Spacebar
  if (key == ' ') {
    if (activeAxis.equals("X")) {
       activeAxis = "Z";
    } else {
       activeAxis = "X";
    }
    println("Active Axis Toggled to: " + activeAxis);
  }

  // Toggle between mouse and physical input
  if (key == 'p' || key == 'P') {
    usePhysicalInput = !usePhysicalInput;
    println("Physical input: " + (usePhysicalInput ? "ON" : "OFF"));
  }
  
  // Handle numeric input for Spindle Speed
  if (activeField == 1) {
    if (key >= '0' && key <= '9') {
      if (spindleStr.equals("0")) spindleStr = "";
      spindleStr += key;
      spindleRPM = float(spindleStr);
      updateCuttingParameters();
    } else if (key == BACKSPACE) {
      if (spindleStr.length() > 0) {
        spindleStr = spindleStr.substring(0, spindleStr.length()-1);
        if (spindleStr.length() == 0) spindleStr = "0";
        spindleRPM = float(spindleStr);
        updateCuttingParameters();
      }
    }
  }
}

// Helper function to get current skill level
String getSkillLevel() {
  if (beginnerSelected) return "beginner";
  if (intermediateSelected) return "intermediate";
  if (advancedSelected) return "advanced";
  return "beginner";
}
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
  String stockLine;
  String opLine;
  String datumLine;

  boolean anyScenario = facingSelected || turnDiaSelected || boringSelected || customSelected;

  // ----- Skill-based tolerance string -----
  boolean anySkill = beginnerSelected || intermediateSelected || advancedSelected;
  String tolStr;

  if (!anySkill || beginnerSelected) {
    tolStr = "± 0.010 in";
  } else if (intermediateSelected) {
    tolStr = "± 0.005 in";
  } else {
    tolStr = "± 0.002 in";
  }

  // ----- Operation-dependent text, using tolStr -----
  if (facingSelected || !anyScenario) {
    stockDiameterIn = 1.25;
    stockLengthIn   = 4.50;
    stockLine = "• Stock: Ø " + nf(stockDiameterIn, 1, 2) + " in x " +
                nf(stockLengthIn, 1, 2) + " in";
    opLine    = "• Operation: Facing to overall length 4.000 " + tolStr;
    datumLine = "• Datum: Chuck face (Z = 0.000 in)";
  } else if (turnDiaSelected) {
    stockDiameterIn = 1.25;
    stockLengthIn   = 4.00;
    stockLine = "• Stock: Ø " + nf(stockDiameterIn, 1, 2) + " in x " +
                nf(stockLengthIn, 1, 2) + " in";
    opLine    = "• Operation: Turn shoulder to Ø 1.000 " + tolStr;
    datumLine = "• Datum: Shoulder location from Z = 0.000 in";
  } else if (boringSelected) {
    stockDiameterIn = 2.00;
    stockLengthIn   = 3.00;
    stockLine = "• Stock: Ø " + nf(stockDiameterIn, 1, 2) + " in x " +
                nf(stockLengthIn, 1, 2) + " in (pre-drilled)";
    opLine    = "• Operation: Bore ID to Ø 1.000 " + tolStr;
    datumLine = "• Datum: Bore start at Z = 0.000 in";
  } else {
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

  // Allow full length so facing is visible
  stockHPx   = min(stockHPx, workspaceH * 0.6);

  // Chuck
  noFill();
  stroke(0);
  rect(chuckX - chuckW, centerY - chuckH / 2, chuckW, chuckH);
  line(chuckX - chuckW, centerY - 30, chuckX, centerY - 15);
  line(chuckX - chuckW, centerY + 30, chuckX, centerY + 15);

  // Stock geometry
  float stockRightX   = chuckX + stockLenPx;
  float stockRadiusPx = stockHPx / 2.0;

  // ===== STATIC STOCK, NO WOBBLE =====
  fill(180);
  stroke(0);
  beginShape();
  // Top edge
  for (int i = 0; i < stockLenPx; i++) {
    if (i < stockProfileLen) {
      float r = stockProfile[i];
      vertex(chuckX + i, centerY - r);   // no yOffset
    }
  }
  // Right face
  float lastR = (stockLenPx < stockProfileLen) ? stockProfile[int(stockLenPx)-1] : 0;
  vertex(chuckX + stockLenPx, centerY - lastR);
  vertex(chuckX + stockLenPx, centerY + lastR);
  // Bottom edge
  for (int i = int(stockLenPx) - 1; i >= 0; i--) {
    if (i < stockProfileLen) {
      float r = stockProfile[i];
      vertex(chuckX + i, centerY + r);   // no yOffset
    }
  }
  // Left face (chuck side)
  vertex(chuckX, centerY + stockHPx/2);
  vertex(chuckX, centerY - stockHPx/2);
  endShape(CLOSE);

  // Optional: simple centerline instead of wavy line
  stroke(100);
  line(chuckX, centerY, chuckX + stockLenPx, centerY);

  // ===== TOOL MOTION & HAPTICS (unchanged) =====
  // Update tool position based on input mode and active axis
  if (usePhysicalInput && bridgeConnected) {
    if (firstBridgeUpdate) {
      lastHandlePosition = physicalHandlePosition;
      firstBridgeUpdate = false;
    } else {
      float delta = physicalHandlePosition - lastHandlePosition;
      lastHandlePosition = physicalHandlePosition;

      float movementScale = 1.0;
      if (activeAxis.equals("Z")) {
        currentToolZ += delta * movementScale;
      } else {
        currentToolX -= delta * movementScale;
      }
    }
    toolTipXpx = currentToolZ;
    toolTipYpx = currentToolX;
  } else {
    toolTipXpx = currentToolZ;
    toolTipYpx = currentToolX;
  }

  // --- Tool dimensions ---
  float toolShankW = 12;
  float toolShankH = 60;
  
  // --- Orange cutting tip (right triangle pointing UP) ---
  float tipL = 12;  // length of triangle (matches shank width)
  float tipH = 10;  // height of triangle

  fill(255, 165, 0);
  stroke(0);
  triangle(
    toolTipXpx - toolShankW/2,         toolTipYpx,              // top point (cutting tip)
    toolTipXpx - toolShankW/2,         toolTipYpx + tipH,       // bottom left (vertical edge)
    toolTipXpx - toolShankW/2 + tipL,  toolTipYpx + tipH        // bottom right
  );

  // --- Vertical shank below the insert ---
  float toolShankX = toolTipXpx - toolShankW / 2;
  float toolShankY = toolTipYpx + tipH;

fill(180);
stroke(0);
rect(toolShankX, toolShankY, toolShankW, toolShankH);


  
  // Tool post position
  float postCenterX = toolTipXpx;
  float postCenterY = toolShankY + toolShankH + 40 - 10;

  fill(255);
  stroke(0);
  rect(postCenterX - 20, postCenterY - 40, 40, 80);

  // ----- Compute tool X/Z positions in inches from toolTip and geometry -----
  rawZIn = (toolTipXpx - chuckX) / pxPerIn;
  rawXIn = (centerY - toolTipYpx) / pxPerIn;
  xPosIn = rawXIn - xZeroOffsetIn;
  zPosIn = rawZIn - zZeroOffsetIn;

  // ----- Collision Detection & Stock Removal -----
  toolCollision = false;
  float maxPenetration = 0;
  
  // Interpolate between previous and current position to avoid missing material
  int interpSteps = firstFrame ? 1 : 10; // More steps = smoother cutting, no spikes
  
  for (int step = 0; step < interpSteps; step++) {
    float t = interpSteps == 1 ? 1.0 : (float)step / (float)(interpSteps - 1);
    
    // Interpolated tool position
    float interpToolTipX = firstFrame ? toolTipXpx : lerp(prevToolTipXpx, toolTipXpx, t);
    float interpToolTipY = firstFrame ? toolTipYpx : lerp(prevToolTipYpx, toolTipYpx, t);
    
    // Check collision along the vertical left edge of the triangle
    float cuttingEdgeX = interpToolTipX - toolShankW/2;
    
    // Sample multiple points along the vertical cutting edge
    int numSamples = 5;
    for (int i = 0; i <= numSamples; i++) {
      float sampleY = interpToolTipY + (tipH * i / numSamples);
      
      // Convert to radial distance from centerline
      float toolRadialDist = abs(centerY - sampleY);
      
      // Get Z position in stock coordinates
      float zPosInStock = cuttingEdgeX - chuckX;
      
      // Check if this point is within the stock length
      if (zPosInStock >= 0 && zPosInStock < stockLenPx) {
        int stockIndex = int(zPosInStock);
        
        if (stockIndex >= 0 && stockIndex < stockProfileLen) {
          float currentStockRadius = stockProfile[stockIndex];
          
          // Check if tool is penetrating the stock
          if (toolRadialDist < currentStockRadius) {
            toolCollision = true;
            float penetration = currentStockRadius - toolRadialDist;
            maxPenetration = max(maxPenetration, penetration);
            
            // Spindle-dependent behavior
            if (spindleRPM > 0) {
               // Cutting: Remove material - update stock profile to new radius
               stockProfile[stockIndex] = min(stockProfile[stockIndex], toolRadialDist);
            } else {
               // Spindle Stopped: Virtual Wall (Do NOT remove material)
               // Penetration remains high, creating a stiff spring force
            }
          }
        }
      }
    }
  }
  
  // Store current position for next frame's interpolation
  prevToolTipXpx = toolTipXpx;
  prevToolTipYpx = toolTipYpx;
  firstFrame = false;
  
  // Calculate and send haptic feedback based on collision
  if (toolCollision) {
    if (spindleRPM > 0) {
      // Cutting Force: Proportional to depth of cut (chip load)
      // Since we remove material instantly, maxPenetration captures the "cut depth" for this frame
      currentForce = maxPenetration * 40.0; 
      
      // Add texture vibration if cutting
      float vibrationFreq = spindleRPM / 60.0; 
      float vibrationAmp = currentForce * 0.3; 
      float vibration = sin(millis() / 1000.0 * vibrationFreq * TWO_PI) * vibrationAmp;
      currentForce += vibration;
      
    } else {
      // Virtual Wall Force: Stiffer spring to resist penetration
      currentForce = maxPenetration * 150.0; // Higher stiffness for wall
    }
    
    currentForce = constrain(currentForce, 0, 100); // Limit max force
    
    // Send force command to bridge if it changed significantly
    if (abs(currentForce - lastSentForce) > 1.0) {
      JSONObject forceCmd = new JSONObject();
      forceCmd.setString("type", "set_force");
      forceCmd.setFloat("force", currentForce);
      sendToBridge(forceCmd.toString());
      lastSentForce = currentForce;
    }
  } else {
    // No collision - release force
    if (lastSentForce > 0) {
      JSONObject forceCmd = new JSONObject();
      forceCmd.setString("type", "set_force");
      forceCmd.setFloat("force", 0.0);
      sendToBridge(forceCmd.toString());
      lastSentForce = 0;
      currentForce = 0;
    }
  }
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
  textSize(13);
  textAlign(CENTER, CENTER);
  text("Lathe Mode", toggleX + toggleW / 4, toggleY + toggleH / 2);

  // Add connection status indicator
  fill(bridgeConnected ? color(0, 200, 0) : color(200, 0, 0));
  noStroke();
  ellipse(W - 30, headerH / 2, 12, 12);

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

  String status = "Status: ";
  if (bridgeConnected) {
    status += "Connected • ";
    status += (usePhysicalInput ? "Physical Input" : "Mouse Input");
    if (millis() - lastHeartbeat > heartbeatInterval) {
      status += " • CONNECTION LOST";
    } else {
      status += " • Handle: " + nf(physicalHandlePosition, 0, 1) + "°";
    }
  } else {
    status += "Disconnected • Mouse Input Only";
  }

  text(status, padding, y + footerH / 2);
}

// Add motor control section to right panel
void drawMotorControl(float x, float y, float w, float h) {
  drawSubPanelBox(x, y, w, h, "Motor Control");

  float innerX = x + 10;
  float innerY = y + 35;
  float btnW = (w - 30) / 3;
  float btnH = 25;
  float spacing = 8;

  // Motor control buttons
  // Row 1: Forward, Stop, Reverse
  drawControlButton(innerX, innerY, btnW, btnH, "Forward", color(0, 180, 0));
  drawControlButton(innerX + btnW + spacing, innerY, btnW, btnH, "Stop", color(180, 0, 0));
  drawControlButton(innerX + 2*(btnW + spacing), innerY, btnW, btnH, "Reverse", color(0, 100, 200));

  innerY += btnH + spacing;

  // Row 2: Slow, Medium, Fast speed buttons
  drawControlButton(innerX, innerY, btnW, btnH, "Slow", color(150, 150, 150));
  drawControlButton(innerX + btnW + spacing, innerY, btnW, btnH, "Medium", color(100, 100, 100));
  drawControlButton(innerX + 2*(btnW + spacing), innerY, btnW, btnH, "Fast", color(50, 50, 50));

  innerY += btnH + spacing + 10;

  // Axis selector (X/Z)
  fill(0);
  textSize(11);
  text("Active Axis:", innerX, innerY);
  innerY += 16;
  
  float axisBtnW = (w - 30) / 2;
  float axisBtnH = 22;
  color xColor = (activeAxis.equals("X")) ? color(100, 200, 100) : color(200, 200, 200);
  color zColor = (activeAxis.equals("Z")) ? color(100, 200, 100) : color(200, 200, 200);
  
  drawControlButton(innerX, innerY, axisBtnW, axisBtnH, "X (Radial)", xColor);
  drawControlButton(innerX + axisBtnW + 5, innerY, axisBtnW, axisBtnH, "Z (Axial)", zColor);
  innerY += axisBtnH + 10;

  // Position readout and controls
  fill(0);
  textSize(12);
  text("Encoder Position: " + nf(physicalHandlePosition, 0, 2) + "°", innerX, innerY);
  innerY += 18;

  // Manual position control
  float posBtnW = (w - 40) / 4;
  float posBtnH = 20;

  drawControlButton(innerX, innerY, posBtnW, posBtnH, "-10°", color(200, 200, 200));
  drawControlButton(innerX + posBtnW + 5, innerY, posBtnW, posBtnH, "-1°", color(200, 200, 200));
  drawControlButton(innerX + 2*(posBtnW + 5), innerY, posBtnW, posBtnH, "+1°", color(200, 200, 200));
  drawControlButton(innerX + 3*(posBtnW + 5), innerY, posBtnW, posBtnH, "+10°", color(200, 200, 200));

  innerY += posBtnH + 10;

  // Current motor status
  fill(0);
  textSize(11);
  text("Motor Status: " + (bridgeConnected ? "Connected" : "Disconnected"), innerX, innerY);
  innerY += 14;
  text("Speed: " + (bridgeConnected ? "Variable RPM" : "N/A"), innerX, innerY);
}

// Helper function to draw control buttons
void drawControlButton(float x, float y, float w, float h, String label, color btnColor) {
  // Button background
  fill(btnColor);
  stroke(0);
  rect(x, y, w, h, 5);

  // Button text
  fill(0);
  textSize(10);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2);
  textAlign(LEFT, CENTER);
}

// Modify drawRightPanel to include motor control section
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

  // Live readouts (existing)
  drawSubPanelBox(innerX, innerY, sectionW, 140, "Live Readouts");
  float lineY = innerY + 40;
  float lineH = 22;
  fill(0);
  textSize(14);
  text("X Position:   " + nfp(xPosIn, 1, 3) + " in", innerX + 10, lineY); lineY += lineH;
  text("Z Position:   " + nfp(zPosIn, 1, 3) + " in", innerX + 10, lineY); lineY += lineH;
  text("Tool Load Fx: " + nfp(currentForce, 1, 1) + " N", innerX + 10, lineY); lineY += lineH;
  text("Tool Load Fz: 0.0 N",     innerX + 10, lineY); lineY += lineH;

  innerY += 150;

  // Cutting parameters (existing)
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

  // Tolerance summary (existing)
  drawSubPanelBox(innerX, innerY, sectionW, 120, "Tolerance Summary");
  lineY = innerY + 40;

  // Skill-based tolerance
  boolean anySkill2 = beginnerSelected || intermediateSelected || advancedSelected;
  String tolStr2;
  if (!anySkill2 || beginnerSelected) {
    tolStr2 = "± 0.010 in";
  } else if (intermediateSelected) {
    tolStr2 = "± 0.005 in";
  } else {
    tolStr2 = "± 0.002 in";
  }

  fill(0);
  textSize(12);
  text("Current tolerance: " + tolStr2, innerX + 10, lineY);
  lineY += 18;
  text("Position accuracy depends on", innerX + 10, lineY);
  lineY += 14;
  text("skill level and setup precision.", innerX + 10, lineY);

  innerY += 130;

  // Add motor control section at the bottom
  float motorControlH = h - (innerY - y) - padding;
  if (motorControlH > 100) {  // Only draw if there's enough space
    drawMotorControl(innerX, innerY, sectionW, motorControlH);
  }
}

// Main draw loop
void draw() {
  background(bgColor);

  // Check bridge connection status periodically
  if (frameCount % 60 == 0) {  // Check every second
    checkBridgeConnection();
  }

  // Check for incoming bridge messages
  checkBridgeMessages();

  drawHeader();
  drawFooter();
  drawLeftPanel();
  drawMainView();   // compute tool tip + X/Z first
  drawRightPanel(); // then use them in live readouts

  // Request status updates periodically
  if (bridgeConnected && frameCount % 30 == 0) {  // Every 0.5 seconds at 60fps
    sendToBridge("{\"type\":\"status_request\"}");
  }
}

// Add parameter sending when values change
void updateCuttingParameters() {
  if (bridgeConnected) {
    JSONObject params = new JSONObject();
    params.setString("type", "set_parameters");
    params.setFloat("spindle_rpm", spindleRPM);
    params.setFloat("feed_rate", feedRate);
    sendToBridge(params.toString());
  }
}

// Hit-test helper function
boolean overRect(float x, float y, float w, float h) {
  return (mouseX >= x && mouseX <= x + w &&
          mouseY >= y && mouseY <= y + h);
}

// Helper functions from original GUI
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
  rect(x, y, w, h, h / 2);     // rounded corners
  fill(0);
  textSize(12);
  textAlign(CENTER, CENTER);
  text(label, x + w / 2, centerY);
  textAlign(LEFT, CENTER);
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
  rect(x, y, w, h);
  fill(0);
  textSize(12);
  textAlign(CENTER, CENTER);
  text(label, x + w / 2, centerY);
  textAlign(LEFT, CENTER);
}

void drawSubPanelBox(float x, float y, float w, float h, String title) {
  fill(255);
  stroke(0);
  rect(x, y, w, h);
  fill(0);
  textSize(14);
  text(title, x + 8, y + 18);
}
