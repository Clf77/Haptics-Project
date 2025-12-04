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
int lastBridgeUpdate = 0; // Timestamp of last bridge update

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
float toolTipRadiusPx = 5.0;   // Radius of the tool tip (Hyperbolic profile)

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
float vibFreq = 0.0;         // Vibration frequency [Hz]

// Relative Positioning State
float currentToolX = 0;      // Current X position (pixels)
float currentToolZ = 0;      // Current Z position (pixels)
float lastHandlePosition = 0; // Last read encoder position
boolean firstBridgeUpdate = true; // Flag to sync handle

// Velocity Tracking
float prevToolTipXpx = 0;
float prevToolTipYpx = 0;

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
  
  // Set default cutting parameters
  spindleRPM = 800;
  spindleStr = "800";
  feedRate = 0.005;
  feedStr = "0.005";
  depthCut = 0.050;
  docStr = "0.050";
  
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
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"speed\",\"value\":30}");
    println("Motor Speed: Slow");
  } else if (overRect(motorX + btnW + spacing, motorY, btnW, btnH)) {
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"speed\",\"value\":100}");
    println("Motor Speed: Medium");
  } else if (overRect(motorX + 2*(btnW + spacing), motorY, btnW, btnH)) {
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

// Modify drawMainView() to use physical handle position
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

  // Keep stock from overflowing the workspace too crazily
  // stockLenPx = min(stockLenPx, innerW * 0.75); // Removed to allow facing visualization
  stockHPx   = min(stockHPx, workspaceH * 0.6);

  // Chuck
  noFill();
  stroke(0);
  rect(chuckX - chuckW, centerY - chuckH / 2, chuckW, chuckH);
  line(chuckX - chuckW, centerY - 30, chuckX, centerY - 15);
  line(chuckX - chuckW, centerY + 30, chuckX, centerY + 15);

  // Stock (simulated rotation)
  float stockRightX = chuckX + stockLenPx;
  float stockBottomY = centerY + stockHPx / 2;
  float stockTopY    = centerY - stockHPx / 2;
  float stockRadiusPx = stockHPx / 2.0;  // Define radius early for use in tool positioning

  // Simulated rotation (simple sine wave for demo)
  float t = millis() / 1000.0;
  float angularPos = TWO_PI * spindleRPM * t / 60.0;

  fill(180);
  stroke(0);
  
  // Render Stock Profile using beginShape
  beginShape();
  // Top edge
  for (int i = 0; i < stockLenPx; i++) {
    if (i < stockProfileLen) {
      float r = stockProfile[i];
      // STRAIGHT VISUALS - No wobble
      vertex(chuckX + i, centerY - r);
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
      // STRAIGHT VISUALS - No wobble
      vertex(chuckX + i, centerY + r);
    }
  }
  // Left face (chuck side)
  vertex(chuckX, centerY + stockHPx/2); 
  vertex(chuckX, centerY - stockHPx/2);
  endShape(CLOSE);

  // Draw a wavy line to simulate rotating stock
  stroke(0);
  noFill();
  beginShape();
  for (float px = 0; px < stockLenPx; px += 5) {
    // STRAIGHT CENTERLINE - No wobble
    vertex(chuckX + px, centerY);
  }
  endShape();

  // Update tool position based on input mode and active axis
  if (usePhysicalInput) {    // Send to Python Bridge
    if (bridgeConnected) {
       // Limit update rate to avoid flooding
       if (millis() - lastBridgeUpdate > 10) { // 100Hz updates
           // Send forces
           // We need to send Fx (Radial) and Fz (Axial)
           // We use currentForce which is already signed based on forceSign
           
           float sendFx = 0;
           float sendFz = 0;
           
           if (activeAxis.equals("X")) {
               sendFx = currentForce; 
           } else {
               sendFz = currentForce; 
           }
           
           // Send
           bridgeClient.write("FORCE:" + nf(sendFx, 0, 2) + "," + nf(sendFz, 0, 2) + "," + nf(vibFreq, 0, 1) + "\n");
           lastBridgeUpdate = millis();
       }
    // Relative positioning logic
    if (firstBridgeUpdate) {
      // First update - just sync the handle position
      lastHandlePosition = physicalHandlePosition;
      firstBridgeUpdate = false;
    } else {
      // Calculate delta
      float delta = physicalHandlePosition - lastHandlePosition;
      lastHandlePosition = physicalHandlePosition;
      
      // Apply movement scale (sensitivity)
      float movementScale = 1.0; 
      
      if (activeAxis.equals("Z")) {
        // Z-axis (axial): Move tool along Z
        // Positive delta = Move Right (Positive Z)
        currentToolZ += delta * movementScale;
      } else {
        // X-axis (radial): Move tool in/out
        // Positive delta (CW) = Move IN (Negative X / smaller diameter)
        // Negative delta (CCW) = Move OUT (Positive X / larger diameter)
        currentToolX -= delta * movementScale;
      }
    }
    
    // Update display coordinates from logical coordinates
    toolTipXpx = currentToolZ;
    toolTipYpx = currentToolX;
    
  } else {
    // Default position when not using physical input - OUTSIDE stock
    // Or just keep last known position
    toolTipXpx = currentToolZ;
    toolTipYpx = currentToolX;
  }
  
  // --- Calculate Tool Velocity (Pixels/Frame) ---
  float velX = toolTipXpx - prevToolTipXpx; // Axial velocity (Z-axis in machine coords)
  float velY = toolTipYpx - prevToolTipYpx; // Radial velocity (X-axis in machine coords)
  
  // Store for next frame
  prevToolTipXpx = toolTipXpx;
  prevToolTipYpx = toolTipYpx;
  
  // Convert to meaningful units if needed, but pixels/frame is fine for relative damping
  // Positive velX = Moving Right (Axial +)
  // Positive velY = Moving Down (Radial - / Inward)

  // --- Orange cutting tip (triangle) pointing upward ---
  float tipW = 12;
  float tipH = 10;

  fill(255, 165, 0);
  stroke(0);
  // Hyperbolic Tool Shape
  beginShape();
  float halfW = tipW / 2.0;
  float slope = tipH / halfW;
  // Draw left side, tip, right side
  for (float tx = -halfW; tx <= halfW; tx += 1.0) {
      float dist = abs(tx);
      // Hyperbolic formula: sqrt((slope*x)^2 + R^2) - R
      float yOffset = sqrt(pow(dist * slope, 2) + pow(toolTipRadiusPx, 2)) - toolTipRadiusPx;
      vertex(toolTipXpx + tx, toolTipYpx + yOffset);
  }
  // Close the shape at the top
  vertex(toolTipXpx + halfW, toolTipYpx + tipH);
  vertex(toolTipXpx - halfW, toolTipYpx + tipH);
  endShape(CLOSE);

  // --- Vertical shank below the tip ---
  float toolShankW = 12;
  float toolShankH = 60;
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

  // Apply zero offsets for displayed readout
  xPosIn = rawXIn - xZeroOffsetIn;
  zPosIn = rawZIn - zZeroOffsetIn;
  
  // Calculate distance from tool tip to stock surface (Needed for collision checks)
  float toolTipDistFromCenter = abs(toolTipYpx - centerY);
  
  // ----- Damping-Based Force Logic -----
  // We replace the Virtual Wall (Spring) with a Resistive Damping Force.
  // Force = -1 * DampingCoeff * Penetration(Depth) * Velocity
  
  float dampingForce = 0.0;
  boolean checkCollision = false;
  float dampingCoeff = 2.0; // Tune this for feel (start low)
  
  // We need to track penetration for depth-of-cut scaling
  boolean axialCollision = false;
  boolean radialCollision = false;
  float axialDepth = 0;
  float radialDepth = 0;
    
    // 1. Check Axial (Facing)
    int faceIdx = int(stockLenPx) - 1;
    float faceRadius = (faceIdx >= 0 && faceIdx < stockProfileLen) ? stockProfile[faceIdx] : 0;
    
    if (toolTipDistFromCenter <= faceRadius + 2.0) {
      float distFromFacePx = toolTipXpx - stockRightX;
      
      if (distFromFacePx < 0) {
        // Material Removal logic remains same
        float yieldBufferPx = 1.0;
        float penPx = abs(distFromFacePx);
        if (penPx > yieldBufferPx) {
           stockLengthIn -= (penPx - yieldBufferPx) / pxPerIn; 
           stockLenPx = stockLengthIn * pxPerIn;
           stockRightX = chuckX + stockLenPx;
        }
      }
    }
    
    // 2. Check Radial (Turning) - V-TOOL LOGIC
    float toolHalfWidth = tipW / 2.0;
    float effectiveToolX = round(toolTipXpx);
    int startZ = floor(effectiveToolX - toolHalfWidth - chuckX) - 2;
    int endZ = ceil(effectiveToolX + toolHalfWidth - chuckX) + 2;
    startZ = max(0, startZ);
    endZ = min(stockProfileLen - 1, endZ);
    
    float maxRadialPenetrationPx = 0;
    float netAxialAreaPx = 0; 
    
    for (int z = startZ; z <= endZ; z++) {
       if (z >= 0 && z < stockProfileLen) {
          float distFromTipX = abs((chuckX + z) - effectiveToolX);
          float physicsSlope = tipH / (tipW / 2.0);
          float toolRadiusAtZ = 0;
          if (distFromTipX < (tipW/2.0)) {
             toolRadiusAtZ = toolTipDistFromCenter + (sqrt(pow(distFromTipX * physicsSlope, 2) + pow(toolTipRadiusPx, 2)) - toolTipRadiusPx);
          } else {
             float yAtEdge = sqrt(pow((tipW/2.0) * physicsSlope, 2) + pow(toolTipRadiusPx, 2)) - toolTipRadiusPx;
             float slopeLinear = (tipH - yAtEdge) / (tipW/2.0);
             toolRadiusAtZ = toolTipDistFromCenter + yAtEdge + (distFromTipX - tipW/2.0) * slopeLinear;
           }
          
          float distFromSurface = toolRadiusAtZ - stockProfile[z];
          if (distFromSurface < 0) {
             radialCollision = true;
             float penPx = -distFromSurface;
             if (penPx > maxRadialPenetrationPx) maxRadialPenetrationPx = penPx;
             
             float zPos = chuckX + z;
             float sideSign = (zPos < effectiveToolX) ? 1.0 : -1.0; 
             netAxialAreaPx += penPx * sideSign;

             // Material Removal
             float yieldBufferPx = 1.0;
             float newRadius = toolRadiusAtZ + yieldBufferPx;
             if (penPx > yieldBufferPx) {
                if (stockProfile[z] > newRadius) {
                    stockProfile[z] = newRadius;
                }
             }
          }
       }
    }
    
    if (radialCollision) {
       radialDepth = maxRadialPenetrationPx / pxPerIn * 0.0254; // meters
    }
    
    // Axial Depth from Net Area
    float netAreaIn2 = netAxialAreaPx / (pxPerIn * pxPerIn);
    float netAreaM2 = netAreaIn2 * 0.00064516; 
    axialDepth = abs(netAreaM2) * 100.0; // Scale area to effective depth metric
    
    if (axialDepth > 0.00001) axialCollision = true;
    
    // --- CALCULATE DAMPING FORCE ---
    // Force opposes velocity.
    // F = -c * depth * v
    
    float forceSign = 0;
    
    if (activeAxis.equals("Z") && axialCollision) {
       // Axial Damping
       // Velocity: velX (pixels/frame). 
       // If moving Right (velX > 0), Force should be Left (Negative).
       // If moving Left (velX < 0), Force should be Right (Positive).
       // Force ~ -velX
       
       // Only apply if moving
       if (abs(velX) > 0.01) { // Lowered threshold from 0.1
           float vMetric = velX; // Use raw pixels/frame as velocity metric for now
           float resistance = dampingCoeff * axialDepth * 500000.0; // INCREASED GAIN 10x (Total 100x)
           dampingForce = -1.0 * resistance * vMetric;
           
           // Clamp
           if (dampingForce > 50) dampingForce = 50;
           if (dampingForce < -50) dampingForce = -50;
           
           currentForce = dampingForce;
           checkCollision = true;
           
           println("🔵 AXIAL DAMPING: Depth=" + nf(axialDepth,0,5) + ", Vel=" + nf(velX,0,2) + ", F=" + currentForce);
       }
       
    } else if (activeAxis.equals("X") && radialCollision) {
       // Radial Damping
       
       if (velY > 0.01) { // Lowered threshold from 0.1
           float vMetric = velY;
           float resistance = dampingCoeff * radialDepth * 2000000.0; // INCREASED GAIN 10x (Total 100x)
           dampingForce = -1.0 * resistance * vMetric; // Negative force pushes OUT
           
           // Clamp
           if (dampingForce > 50) dampingForce = 50;
           if (dampingForce < -50) dampingForce = -50;
           
           currentForce = dampingForce;
           checkCollision = true;
           
           println("🔵 RADIAL DAMPING: Depth=" + nf(radialDepth,0,5) + ", Vel=" + nf(velY,0,2) + ", F=" + currentForce);
       }
    }
    
    // DEBUG: Print State every second
    if (frameCount % 60 == 0) {
        println("🔍 STATE: Axis=" + activeAxis + ", VelX=" + nf(velX,0,2) + ", VelY=" + nf(velY,0,2) + 
                ", RadColl=" + radialCollision + ", AxColl=" + axialCollision + ", F=" + currentForce);
    }
    
    // DISABLE VIBRATION
    vibFreq = 0.0;
    
    // Visual feedback
    if (checkCollision) {
       toolCollision = true;
    } else {
       currentForce = 0;
       toolCollision = false;
    }


  
  // Visual feedback for collision
  if (toolCollision) {
    // Flash tool tip red when colliding
    // REMOVED per user request - logic is now side-aware
    // fill(255, 0, 0, 150);
    // noStroke();
    // ellipse(toolTipXpx, toolTipYpx, 20, 20);
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
  
  // DEBUG: Display SFM and Frequency
  if (vibFreq > 0) {
      fill(0);
      textSize(16);
      textAlign(RIGHT, CENTER);
      text("SFM: " + nf(vibFreq, 0, 1) + " | Vib: " + nf(vibFreq, 0, 1) + "Hz", toggleX - 20, headerH / 2);
  }

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

  if (frameCount % 60 == 0) {  // Check every second
    checkBridgeConnection();
  }

  // Check for incoming bridge messages
  checkBridgeMessages();

  // Draw Order:
  // 1. Main View (Calculates Physics & Haptics)
  // 2. Header (Displays SFM/Vib from Main View)
  // 3. Panels & Footer
  
  drawMainView();   // compute tool tip + X/Z first
  
  // DEBUG: Check vibFreq after MainView
  if (frameCount % 60 == 0 && vibFreq > 0) {
      println("DEBUG: Post-MainView Vib=" + vibFreq);
  }
  
  drawHeader();     // Now sees updated vibFreq
  drawFooter();
  drawLeftPanel();
  drawRightPanel(); 

  // Request status updates periodically
  if (bridgeConnected && frameCount % 30 == 0) {  // Every 0.5 seconds at 60fps
    sendToBridge("{\"type\":\"status_request\"}");
  }
  
  // Send Forces to Python Bridge (Moved to end of draw to ensure all calculations are done)
  if (bridgeConnected) {
       // Limit update rate to avoid flooding
       if (millis() - lastBridgeUpdate > 10) { // 100Hz updates
           // Send forces
           // We need to send Fx (Radial) and Fz (Axial)
           // We use currentForce which is already signed based on forceSign
           
           float sendFx = 0;
           float sendFz = 0;
           
           if (activeAxis.equals("X")) {
               sendFx = currentForce; 
           } else {
               sendFz = currentForce; 
           }
           
           // Send
           // DEBUG: Print what we are sending
           // Only print if force is non-zero to reduce noise, OR periodically
           if (currentForce != 0 || frameCount % 60 == 0) {
              println("DEBUG SEND: Axis=" + activeAxis + ", Fx=" + nf(sendFx, 0, 2) + ", Fz=" + nf(sendFz, 0, 2) + ", Vib=" + nf(vibFreq, 0, 1) + ", curF=" + currentForce);
           }
           
           bridgeClient.write("FORCE:" + nf(sendFx, 0, 2) + "," + nf(sendFz, 0, 2) + "," + nf(vibFreq, 0, 1) + "\n");
           lastBridgeUpdate = millis();
       }
  } else {
      if (frameCount % 60 == 0) {
          println("DEBUG: Bridge NOT Connected!");
      }
  }
  
  // Reset per-frame variables for NEXT frame
  toolCollision = false;
  collisionForce = 0;
  currentForce = 0;
  vibFreq = 0.0; 
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
