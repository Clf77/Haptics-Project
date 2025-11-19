// Haptic Lathe Simulator GUI - Integrated with Physical Motor
// - Serial communication with Python bridge
// - Handle wheel position input from motor encoder
// - Real-time haptic feedback

// File-based communication with Python bridge
String bridgeStatusFile;
String guiCommandsFile;
boolean bridgeConnected = false;
JSONObject lastStatus;
float physicalHandlePosition = 0.0;  // degrees from motor encoder
boolean usePhysicalInput = true;     // toggle between mouse and physical input
long lastHeartbeat = 0;
int heartbeatInterval = 1000;        // 1 second timeout

// Original GUI variables (copied from Haptic_Lathe_GUI.pde)
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
boolean zeroXSelected        = false;
boolean zeroZSelected        = false;
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

  // Initialize file-based communication for motor control integration
  String tempDir = System.getProperty("java.io.tmpdir");
  bridgeStatusFile = tempDir + "/lathe_bridge_status.json";
  guiCommandsFile = tempDir + "/lathe_gui_commands.json";

  // Check if bridge is running by looking for status file
  checkBridgeConnection();

  // Send initial status request
  if (bridgeConnected) {
    sendToBridge("{\"type\":\"status_request\"}");
  }
}

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
    // Skill Level (mutually exclusive)
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

  // Now draw the buttons (after hit testing)
  innerY = y + padding + 50;  // reset position for drawing

  drawPillButton(innerX, innerY, "Facing", facingSelected);
  innerY += 30;
  drawPillButton(innerX, innerY, "Turn to Diameter", turnDiaSelected);
  innerY += 30;
  drawPillButton(innerX, innerY, "Boring", boringSelected);

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

// Check if Python bridge is running
void checkBridgeConnection() {
  try {
    File statusFile = new File(bridgeStatusFile);
    bridgeConnected = statusFile.exists();
    if (bridgeConnected) {
      println("Bridge connection established via file: " + bridgeStatusFile);
    } else {
      println("Bridge not connected - waiting for Python controller to start");
    }
  } catch (Exception e) {
    println("Error checking bridge connection: " + e.getMessage());
    bridgeConnected = false;
  }
}

// New function for file-based communication
void sendToBridge(String message) {
  if (bridgeConnected) {
    try {
      // Write command to file for Python bridge to read
      String[] lines = { message };
      saveStrings(guiCommandsFile, lines);
    } catch (Exception e) {
      println("Error sending to bridge: " + e.getMessage());
    }
  }
}

// File-based communication is handled in draw() loop
void checkBridgeMessages() {
  if (bridgeConnected) {
    try {
      File statusFile = new File(bridgeStatusFile);
      if (statusFile.exists()) {
        String[] lines = loadStrings(bridgeStatusFile);
        if (lines != null && lines.length > 0) {
          String data = join(lines, "");
          lastStatus = parseJSONObject(data);
          if (lastStatus != null) {
            processBridgeMessage(lastStatus);
          }
        }
      }
    } catch (Exception e) {
      // File might not exist or be corrupted, ignore
    }
  }
}

void processBridgeMessage(JSONObject msg) {
  String msgType = msg.getString("type", "");

  if (msgType.equals("status_update")) {
    physicalHandlePosition = msg.getFloat("handle_wheel_position", 0.0);
    lastHeartbeat = millis();

    // Update GUI display values
    String mode = msg.getString("mode", "manual");
    String skill = msg.getString("skill_level", "beginner");
    boolean eStop = msg.getBoolean("emergency_stop", false);

    // Update status display
    if (eStop) {
      // Change footer to show emergency stop
      // This would require modifying the footer drawing function
    }
  }
}

// Modify mousePressed() to send commands to bridge
void mousePressed() {
  println("Mouse clicked at: " + mouseX + ", " + mouseY);
  
  // Check parameter field clicks first
  if (overRect(rpmBoxX, rpmBoxY, rpmBoxW, rpmBoxH)) {
    activeField = 1;  // spindle
    println("RPM field clicked");
    return;
  }
  if (overRect(feedBoxX, feedBoxY, feedBoxW, feedBoxH)) {
    activeField = 2;  // feed
    println("Feed field clicked");
    return;
  }
  if (overRect(docBoxX, docBoxY, docBoxW, docBoxH)) {
    activeField = 3;  // doc
    println("DOC field clicked");
    return;
  }
  
  // Click elsewhere = deactivate field
  activeField = 0;

  // Handle motor control buttons FIRST (so they work!)
  println("Checking motor control buttons...");
  handleMotorControlClicks();

  // Then handle left panel buttons...
  // (Rest of the button detection code would go here if needed)
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

  println("Motor control area: motorX=" + motorX + ", motorY=" + motorY + ", btnW=" + btnW + ", btnH=" + btnH);
  println("Button 1: x=" + motorX + ", y=" + motorY + ", w=" + btnW + ", h=" + btnH);
  
  // Check motor direction buttons (Row 1)
  if (overRect(motorX, motorY, btnW, btnH)) {
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"forward\"}");
    println("Motor Forward clicked!");
  } else if (overRect(motorX + btnW + spacing, motorY, btnW, btnH)) {
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"stop\"}");
    println("Motor Stop clicked!");
  } else if (overRect(motorX + 2*(btnW + spacing), motorY, btnW, btnH)) {
    sendToBridge("{\"type\":\"motor_control\",\"action\":\"reverse\"}");
    println("Motor Reverse clicked!");
  } else {
    println("No motor direction button clicked");
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

  // Emergency stop on spacebar
  if (key == ' ') {
    sendToBridge("{\"type\":\"emergency_stop\"}");
    println("EMERGENCY STOP sent to controller");
  }

  // Toggle between mouse and physical input
  if (key == 'p' || key == 'P') {
    usePhysicalInput = !usePhysicalInput;
    println("Physical input: " + (usePhysicalInput ? "ON" : "OFF"));
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

  // Stock (simulated rotation)
  float stockRightX = chuckX + stockLenPx;
  float stockBottomY = centerY + stockHPx / 2;
  float stockTopY    = centerY - stockHPx / 2;

  fill(180);
  stroke(0);
  rect(chuckX, stockTopY, stockLenPx, stockHPx);

  // Simulated rotation (simple sine wave for demo)
  float t = millis() / 1000.0;  // time in seconds
  float angularPos = TWO_PI * spindleRPM * t / 60.0;  // convert RPM to rad/s

  // Draw a wavy line to simulate rotating stock
  stroke(0);
  noFill();
  beginShape();
  for (float px = 0; px < stockLenPx; px += 5) {
    float amp = stockHPx * 0.25;   // 25% of radius up/down
    float yOffset = amp * sin(angularPos + px * 0.1);
    vertex(chuckX + px, centerY + yOffset);
  }
  endShape();

  // Define tool tip position (point of the triangle)
  // toolTipXpx, toolTipYpx REFER TO THE TIP OF THE CUTTING TOOL

  // Update tool position based on input mode
  if (usePhysicalInput && bridgeConnected) {
    // Convert physical handle position to tool coordinates
    // Assuming handle wheel rotation maps to Z-axis movement
    float zMovement = map(physicalHandlePosition, 0, 360, 0, stockLenPx);
    toolTipXpx = chuckX + zMovement;

    // X position could be controlled by another axis or kept static
    toolTipYpx = stockBottomY + 10;
  } else {
    // Original static position or mouse control could be added here
    toolTipXpx = chuckX + stockLenPx * 0.50;
    toolTipYpx = stockBottomY + 10;
  }

  // --- Orange cutting tip (triangle) pointing upward ---
  float tipW = 12;   // width of the base of the triangle
  float tipH = 10;   // height of the triangle

  fill(255, 165, 0);  // orange
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

  // Tool post position (to the right of stock)
  float postCenterX = toolTipXpx;
  float postCenterY = toolShankY + toolShankH + 40 - 10;  // small overlap up

  fill(255);
  stroke(0);
  rect(postCenterX - 20, postCenterY - 40, 40, 80);

  // ----- Compute tool X/Z positions in inches from toolTip and geometry -----
  // Z: distance along the stock from the chuck face
  rawZIn = (toolTipXpx - chuckX) / pxPerIn;

  // X: radial position relative to stock centerline (simple mapping for now)
  rawXIn = (centerY - toolTipYpx) / pxPerIn;

  // Apply zero offsets for displayed readout
  xPosIn = rawXIn - xZeroOffsetIn;
  zPosIn = rawZIn - zZeroOffsetIn;
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
  // Check if mouse is hovering
  boolean hover = overRect(x, y, w, h);
  
  // Button background with hover effect
  if (hover) {
    fill(red(btnColor) + 30, green(btnColor) + 30, blue(btnColor) + 30);  // Lighter when hovering
    stroke(255, 255, 0);  // Yellow border on hover
    strokeWeight(2);
  } else {
    fill(btnColor);
    stroke(0);
    strokeWeight(1);
  }
  rect(x, y, w, h, 5);
  strokeWeight(1);  // Reset stroke weight

  // Button text
  fill(hover ? 255 : 0);  // White text on hover, black otherwise
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
  text("Tool Load Fx: 0.0 N",     innerX + 10, lineY); lineY += lineH;
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

// Simple line with arrowhead
void arrow(float x1, float y1, float x2, float y2) {
  line(x1, y1, x2, y2);
  float angle = atan2(y2 - y1, x2 - x1);
  float len = 20;
  float a1 = angle + radians(150);
  float a2 = angle - radians(150);
  line(x2, y2, x2 - len * cos(a1), y2 - len * sin(a1));
  line(x2, y2, x2 - len * cos(a2), y2 - len * sin(a2));
}

// Hit-test helper
boolean overRect(float x, float y, float w, float h) {
  return (mouseX >= x && mouseX <= x + w &&
          mouseY >= y && mouseY <= y + h);
}
