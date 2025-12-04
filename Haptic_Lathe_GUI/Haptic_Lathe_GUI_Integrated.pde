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
boolean hasCrashed = false;  // True if tool hit stock at 0 RPM

// Relative Positioning State
float currentToolX = 0;      // Current X position (pixels)
float currentToolZ = 0;      // Current Z position (pixels)
float lastHandlePosition = 0; // Last read encoder position
boolean firstBridgeUpdate = true; // Flag to sync handle

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

  // ----- Controls Section -----
  drawSubPanelTitle(innerX, innerY + 10, "Controls");
  innerY += 35;

  // Reset Workpiece (momentary) - just draw, action in mousePressed
  drawOutlinedButton(innerX, innerY, "Reset Workpiece", false);
  innerY += 30;

  // Zero X (momentary) - just draw, action in mousePressed
  drawOutlinedButton(innerX, innerY, "Zero X", false);
  innerY += 30;

  // Zero Z (momentary) - just draw, action in mousePressed
  drawOutlinedButton(innerX, innerY, "Zero Z", false);
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

  // Handle LEFT PANEL control buttons
  float leftInnerX = padding;
  float leftInnerY = headerH + padding + 35;  // Skip header + title
  
  // Reset Workpiece button
  if (overRect(leftInnerX, leftInnerY - 11, 180, 22)) {
    resetFlashStart = millis();
    sendToBridge("{\"type\":\"reset\"}");
    initStockProfile();  // Rebuild the stock
    
    // Calculate initial tool position (same formula as setup)
    float centerY = (headerH + padding + padding) + (H - headerH - footerH - 2*padding) * 0.40;
    float chuckX  = leftPanelW + padding + 100;
    float stockLenPx = stockLengthIn * pxPerIn;
    float stockHPx   = stockDiameterIn * pxPerIn;
    float stockRadiusPx = stockHPx / 2.0;
    
    // Start Z past the right edge of the stock (in empty air)
    currentToolZ = chuckX + stockLenPx + 50;  // 50px past stock end
    
    // Start X well outside the stock (below it)
    currentToolX = centerY + stockRadiusPx + 40; // 40px clearance below
    
    lastHandlePosition = physicalHandlePosition; // Sync encoder
    firstBridgeUpdate = true; // Reset the first update flag
    println("Reset Workpiece: Stock rebuilt, tool @ Z=" + currentToolZ + ", X=" + currentToolX);
  }
  leftInnerY += 30;
  
  // Zero X button
  if (overRect(leftInnerX, leftInnerY - 11, 180, 22)) {
    zeroXFlashStart = millis();
    xZeroOffsetIn = rawXIn;
    sendToBridge("{\"type\":\"zero_position\",\"axis\":\"x\"}");
    println("Zero X clicked");
  }
  leftInnerY += 30;
  
  // Zero Z button
  if (overRect(leftInnerX, leftInnerY - 11, 180, 22)) {
    zeroZFlashStart = millis();
    zZeroOffsetIn = rawZIn;
    sendToBridge("{\"type\":\"zero_position\",\"axis\":\"z\"}");
    println("Zero Z clicked");
  }

  // Handle axis selection buttons (in right panel after Cutting Parameters)
  float x = W - rightPanelW;
  float innerX = x + padding;
  float innerY = headerH + padding;
  innerY += 150;  // Skip Live Readouts
  innerY += 190;  // Skip Cutting Parameters
  innerY += 35;   // Title offset for Axis Selection
  
  float axisBtnW = (rightPanelW - 2 * padding - 15) / 2;
  float axisBtnH = 28;
  
  if (overRect(innerX, innerY, axisBtnW, axisBtnH)) {
    activeAxis = "X";
    sendToBridge("{\"type\":\"axis_select\",\"axis\":\"X\"}");
    println("Axis: X (Radial)");
  } else if (overRect(innerX + axisBtnW + 5, innerY, axisBtnW, axisBtnH)) {
    activeAxis = "Z";
    sendToBridge("{\"type\":\"axis_select\",\"axis\":\"Z\"}");
    println("Axis: Z (Axial)");
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

  // Fixed stock dimensions
  stockDiameterIn = 1.25;
  stockLengthIn   = 4.50;

  // --- Workspace (full height now - drawing section removed) ---
  float workspaceY = innerY;
  float workspaceH = innerH;
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
  // Wave phase based on time and spindle speed
  float wavePhase = millis() / 1000.0 * spindleRPM / 60.0 * TWO_PI;  // Rotate with spindle
  float waveAmplitude = (spindleRPM > 0) ? 3.0 : 0.0;  // Wave only when spinning
  float waveFrequency = 0.05;  // Waves per pixel
  
  for (float px = 0; px < stockLenPx; px += 5) {
    // WAVY CENTERLINE - Simulates rotating stock
    float waveY = sin(px * waveFrequency + wavePhase) * waveAmplitude;
    vertex(chuckX + px, centerY + waveY);
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
  
  // ----- Virtual Wall Force Rendering (Hapkit-style) -----
  // Calculate distance from tool tip to stock surface
  float toolTipDistFromCenter = abs(toolTipYpx - centerY);
  // stockRadiusPx already defined above
  
  float xh = 0.0; // Penetration in meters
  boolean checkCollision = false;

    float collisionMargin = 2.0; // 2px margin for robust detection

    // INTELLIGENT CUTTING LOGIC
    // Check BOTH Axial (Facing) and Radial (Turning) collisions
    // Apply haptics based on which one is happening (or prioritized)
    
    boolean axialCollision = false;
    boolean radialCollision = false;
    float axialPenetration = 0;
    float radialPenetration = 0;
    
    // 1. Check Axial (Facing)
    int faceIdx = int(stockLenPx) - 1;
    float faceRadius = (faceIdx >= 0 && faceIdx < stockProfileLen) ? stockProfile[faceIdx] : 0;
    
    if (toolTipDistFromCenter <= faceRadius + collisionMargin) {
      float distFromFacePx = toolTipXpx - stockRightX;
      
      // DEBUG FACING
      if (frameCount % 60 == 0) {
         println("Face Check: Dist=" + distFromFacePx + ", Radial=" + toolTipDistFromCenter + " vs " + faceRadius);
      }
      
      if (distFromFacePx < 0) {
        // Tool is INSIDE the stock (left of face)
        // Material Removal with Yield Buffer (only when spindle is ON)
        if (spindleRPM > 0) {
          float yieldBufferPx = 1.0;
          float penPx = abs(distFromFacePx);
          if (penPx > yieldBufferPx) {
             // Cut material down, leaving yieldBufferPx
             stockLengthIn -= (penPx - yieldBufferPx) / pxPerIn; 
             stockLenPx = stockLengthIn * pxPerIn;
             stockRightX = chuckX + stockLenPx;
          }
        }
      }
    }
    
    // SEPARATE CHECK: Face wall when approaching from RIGHT (outside, in empty air)
    // This is outside the radial bounds check so it works when tool is outside stock
    // distFromFacePx = toolTipXpx - stockRightX; (positive = in empty air to right)
    float distFromFaceForWall = toolTipXpx - stockRightX;
    
    // DEBUG: Print face-from-right check every 60 frames
    if (frameCount % 60 == 0) {
      println("Face-from-right: distFromFace=" + distFromFaceForWall + ", toolTipDist=" + toolTipDistFromCenter + ", stockRadius=" + stockRadiusPx);
    }
    
    // CRASH DETECTION: Tool hits face from right at 0 RPM
    if (spindleRPM == 0 && distFromFaceForWall >= 0 && distFromFaceForWall <= 5.0) {
      // Tool is in empty air, very close to face (within 5 pixels = contact)
      // AND tool is within the radial bounds of the stock (would hit face)
      if (toolTipDistFromCenter <= stockRadiusPx + collisionMargin) {
        hasCrashed = true;  // CRASH!
      }
    }
    
    // 2. Check Radial (Turning) - V-TOOL LOGIC
    // Iterate over the tool's width to check for collisions with the V-shape
    // 2. Check Radial (Turning) - V-TOOL LOGIC
    // Iterate over the tool's width to check for collisions with the V-shape
    // tipW and tipH are already defined above
    float toolHalfWidth = tipW / 2.0;
    // SNAP TOOL TO INTEGER GRID FOR SYMMETRY
    // This prevents sub-pixel bias where one side cuts deeper than the other.
    float effectiveToolX = round(toolTipXpx);
    
    // Declare variables before if/else block for proper scoping
    float maxRadialPenetrationPx = 0;
    float netAxialAreaPx = 0; // Net axial overlap area (sum of depths)
    int startZ = 0;
    int endZ = 0;
    
    // FIX: If tool is completely past the stock, no RADIAL collision possible!
    // But AXIAL (face) collision can still happen if approaching from right
    // Check if left edge of tool is past right edge of stock
    if (effectiveToolX - toolHalfWidth > stockRightX) {
        // Tool is in empty space - no RADIAL feedback (but axialCollision may still be set from face)
        radialCollision = false;
        // Note: axialCollision is NOT reset here - it was set above if approaching face from right
    } else {
    
    // Determine loop range based on snapped position
    startZ = floor(effectiveToolX - toolHalfWidth - chuckX) - 2;
    endZ = ceil(effectiveToolX + toolHalfWidth - chuckX) + 2;
    
    // Clamp to stock profile bounds (allows full tool width processing)
    startZ = max(0, startZ);
    endZ = min(stockProfileLen - 1, endZ);  // Use profile length for material removal
    
    // DEBUG
    if (frameCount % 30 == 0 && radialCollision) {
        println("DEBUG: startZ=" + startZ + ", endZ=" + endZ + ", toolTipXpx=" + toolTipXpx + ", chuckX=" + chuckX);
    }
    
    for (int z = startZ; z <= endZ; z++) {
       // Check bounds (redundant if clamped but safe)
       if (z >= 0 && z < stockProfileLen) {
          // Distance from snapped tool center
          float distFromTipX = abs((chuckX + z) - effectiveToolX);
          
          // Calculate hyperbolic tool radius at this distance
          // Hyperbolic formula: y = sqrt((slope*x)^2 + R^2) - R
          // Here, x is distFromTipX.
          float physicsSlope = tipH / (tipW / 2.0); // Recalculate slope for clarity
          float toolRadiusAtZ = 0;
          if (distFromTipX < (tipW/2.0)) {
             // Inside the rounded tip region
             toolRadiusAtZ = toolTipDistFromCenter + (sqrt(pow(distFromTipX * physicsSlope, 2) + pow(toolTipRadiusPx, 2)) - toolTipRadiusPx);
          } else {
             // Outside tip, assume linear extension or just cap it
             // For now, let's just continue the hyperbolic shape or linear
             // Linear approximation from the edge of the tip:
             float yAtEdge = sqrt(pow((tipW/2.0) * physicsSlope, 2) + pow(toolTipRadiusPx, 2)) - toolTipRadiusPx;
             float slopeLinear = (tipH - yAtEdge) / (tipW/2.0); // Rough slope
             toolRadiusAtZ = toolTipDistFromCenter + yAtEdge + (distFromTipX - tipW/2.0) * slopeLinear;
           }
          
          // Check collision with stock
          // Collision if Stock Radius > Tool Radius
          float distFromSurface = toolRadiusAtZ - stockProfile[z];
                    if (distFromSurface < 0) {
             // COLLISION DETECTED
             radialCollision = true;
             
             // CRASH: If spindle is 0 and we hit stock, it's a crash
             if (spindleRPM == 0) {
               hasCrashed = true;
             }
             
             // Calculate penetration
             float penPx = -distFromSurface;
             
             // Track maximum radial penetration for X-axis force
             if (penPx > maxRadialPenetrationPx) {
                 maxRadialPenetrationPx = penPx;
             }
             
             // Accumulate Net Axial Area
             // If z < effectiveToolX (Left side), we add positive area?
             // If z > effectiveToolX (Right side), we add negative area?
             // Let's stick to the sign convention:
             // Left Wall (z > toolX? No, z < toolX means we are on the left side of the tool)
             // If we hit material on the LEFT of the tool, it pushes us RIGHT.
             // If we hit material on the RIGHT of the tool, it pushes us LEFT.
             
             float zPos = chuckX + z;
             float sideSign = (zPos < effectiveToolX) ? 1.0 : -1.0; 
             
             // Add to net area
             netAxialAreaPx += penPx * sideSign;

             // VIBRATION FREQUENCY CALCULATION (Dynamic)
    // Calculate Surface Speed (SFM)
    // SFM = (RPM * Diameter_Inches * PI) / 12.0
    // Diameter is 2 * radius (distance from center)
    // We use the tool's current radial position as the cutting diameter
    float cuttingDiameterIn = (toolTipDistFromCenter / pxPerIn) * 2.0;
    float sfm = (spindleRPM * cuttingDiameterIn * PI) / 12.0;
    
    // Map SFM to Frequency
    // User Request: 10 SFM = 10 Hz. So 1:1 mapping.
    // Only vibrate if we are in collision (cutting)
    if (axialCollision || radialCollision) {
        vibFreq = sfm;
        // Clamp minimum frequency to avoid weird low-freq effects? 
        // User said "Lowest SFM (10 sfm) corresponds to 10hz and scale up from there".
        // Let's just use raw SFM for now.
    } else {
        vibFreq = 0.0;
    }
    
              // Material Removal with Yield Buffer
              // ONLY remove material if spindle is running (RPM > 0)
              if (spindleRPM > 0) {
                float yieldBufferPx = 1.0;
                float newRadius = toolRadiusAtZ + yieldBufferPx;
                
                if (penPx > yieldBufferPx) {
                   // Cut material down (ONLY if new radius is smaller)
                   if (stockProfile[z] > newRadius) {
                       stockProfile[z] = newRadius;
                   }
                }
              }
              // When spindle is off, collision is detected but no material removed
              // (virtual wall behavior - 100x damping already applied by Pico)
          }
       }
    }
    
    // PARTING-OFF: When tool TIP passes through center of stock
    // Use toolTipDistFromCenter directly (tool tip Y distance from centerline)
    // effectiveToolX is the tool tip X position, convert to Z index
    if (spindleRPM > 0 && toolTipDistFromCenter <= 10.0) {
      // Tool tip has reached/passed the centerline
      int tipZIndex = int(effectiveToolX - chuckX);
      
      // Remove all material from tool tip position to the end (parting off)
      if (tipZIndex >= 0 && tipZIndex < stockProfileLen) {
        for (int partZ = tipZIndex; partZ < stockProfileLen; partZ++) {
          stockProfile[partZ] = 0;
        }
        // Update stock length
        stockLengthIn = float(tipZIndex) / pxPerIn;
        stockLenPx = stockLengthIn * pxPerIn;
        stockRightX = chuckX + stockLenPx;
      }
      
      // ALSO: Zero out the V-tool groove to the LEFT of the tip (the nub)
      // This removes material the tool shoulders are cutting through
      int leftEdge = max(0, int(effectiveToolX - toolHalfWidth - chuckX));
      for (int grooveZ = leftEdge; grooveZ < tipZIndex && grooveZ < stockProfileLen; grooveZ++) {
        stockProfile[grooveZ] = 0;  // Tool has passed through here - no material left
      }
    }
    
    // DEBUG: Print loop range and netArea
    if (frameCount % 60 == 0 && (radialCollision || axialCollision)) {
        println("🔍 LOOP DEBUG: startZ=" + startZ + ", endZ=" + endZ + ", toolTipXpx=" + toolTipXpx + ", chuckX=" + chuckX);
        println("🔍 NetArea=" + netAxialAreaPx + ", radialColl=" + radialCollision + ", axialColl=" + axialCollision);
    }
    
    if (radialCollision) {
       radialPenetration = maxRadialPenetrationPx / pxPerIn * 0.0254;
    }
    
    // Convert Net Area [px^2] to Effective Penetration [m] for Haptics
    // Force should be proportional to Area.
    // 1. Convert px^2 to m^2
    float netAreaIn2 = netAxialAreaPx / (pxPerIn * pxPerIn);
    float netAreaM2 = netAreaIn2 * 0.00064516; // 1 in^2 = 0.00064516 m^2
    
    // 2. Scale to Effective Penetration
    // We want F = k * x_eff ~ Area.
    // Heuristic: 1mm^2 Area (1e-6 m^2) should feel like ~1mm Penetration (1e-3 m)
    // Scaling Factor = 1000.0 -> REDUCED to 100.0 -> REDUCED by 70% to 30.0
    float effectivePenetrationM = abs(netAreaM2) * 30.0;
    
    // If we have a net axial force, we should flag axial collision too?
    if (effectivePenetrationM > 0.00001) { // Threshold
       // Only override if not hitting the face (which is a hard stop)
       if (!axialCollision) {
          axialCollision = true;
          axialPenetration = effectivePenetrationM;
       }
    }
    
    } // End of "tool is within stock bounds" else block
    
    // 3. Determine Haptic Feedback
    // If activeAxis is Z, we only feel Axial collisions
    // If activeAxis is X, we only feel Radial collisions
    
    float forceSign = 0; // Declare variable for force direction
    
    if (activeAxis.equals("Z") && axialCollision) {
       checkCollision = true;
       xh = axialPenetration;
       
       // FORCE DIRECTION LOGIC FOR Z-AXIS
       // Reverting to previous logic as inversion caused "no feedback".
       // If netAxialAreaPx > 0, we assume we need to push RIGHT? (Or Suction was actually correct direction but unstable?)
       // Let's go back to:
       // NetArea > 0 -> forceSign = -1.0
       // NetArea < 0 -> forceSign = 1.0
       
       if (netAxialAreaPx > 0) {
          forceSign = -1.0; 
       } else if (netAxialAreaPx < 0) {
          forceSign = 1.0;
       } else {
          forceSign = -1.0; // Default
       }
       println("🔴 AXIAL COLLISION (Z) - NetArea: " + netAxialAreaPx + ", Sign: " + forceSign);
    } else if (activeAxis.equals("X") && radialCollision) {
       checkCollision = true;
       // Restore gain for Radial (it needs to be strong to feel the wall)
       // Axial gain was reduced to 100.0, but Radial might need more?
       // Let's try 500.0 as a middle ground
       xh = radialPenetration * 5.0; // Boost radial penetration signal
       
       // Radial: Want Push OUT (Positive X).
       // Handle Logic: Positive Delta (CW) = Move IN. Negative Delta (CCW) = Move OUT.
       // We want to push OUT -> Push Negative (CCW).
       // Pico Logic: wall_dir = 1 -> Push Negative (Left/CCW).
       // So we need wall_dir = 1.
       // Bridge Logic: Force > 0 -> wall_dir = 1.
       // So we need Force > 0.
       forceSign = 1.0; 
       println("🔴 RADIAL COLLISION (X) - Pen: " + radialPenetration + ", ForceSign: " + forceSign);
    } else {
       checkCollision = false;
       xh = 0;
       forceSign = 0;
    }


  // Virtual wall parameters
  float wall_position = 0.0;  // Wall is at surface (0mm penetration)
  float k_wall = 100000.0;    // Wall stiffness [N/m]

  // Calculate force using Hapkit virtual wall algorithm
  float force = 0.0;
  boolean wasColliding = toolCollision; // Capture previous state
  
  if (checkCollision) {
    // Penetrating virtual wall
    float penetration = xh;  // Positive penetration depth
    force = k_wall * penetration;  // Positive force pushes back
    
    // Cap force at maximum
    force = min(force, 50.0);  // Max 50N
    
    // Apply Direction Sign
    force = force * forceSign;
    
    collisionForce = map(force, -50, 50, -100, 100);  // Scale to -100 to 100 range
    currentForce = force;  // Store actual force in Newtons
    toolCollision = true;
    
    println("🔴 COLLISION (" + activeAxis + "): pen=" + (penetration*1000) + "mm, F=" + force + "N");
  } else {
    // Outside virtual wall - no force
    force = 0.0;
    collisionForce = 0.0;
    currentForce = 0.0;
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
  
  // Send to Python Bridge
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

  // Axis Selection (moved here from Motor Control)
  drawSubPanelBox(innerX, innerY, sectionW, 70, "Axis Selection");
  lineY = innerY + 45;
  
  float axisBtnW = (sectionW - 15) / 2;
  float axisBtnH = 28;
  
  color xColor = (activeAxis.equals("X")) ? color(100, 200, 100) : color(200, 200, 200);
  color zColor = (activeAxis.equals("Z")) ? color(100, 200, 100) : color(200, 200, 200);
  
  drawControlButton(innerX, lineY - 10, axisBtnW, axisBtnH, "X (Radial)", xColor);
  drawControlButton(innerX + axisBtnW + 5, lineY - 10, axisBtnW, axisBtnH, "Z (Axial)", zColor);
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

  // CRASH OVERLAY: Show if tool hit stock at 0 RPM
  if (hasCrashed) {
    // Dark red overlay
    fill(150, 0, 0, 200);
    noStroke();
    rect(0, 0, width, height);
    
    // Crash message
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(72);
    text("YOU CRASHED!", width/2, height/2 - 40);
    textSize(24);
    text("Tool hit stock with spindle off", width/2, height/2 + 30);
    text("Restart the program to continue", width/2, height/2 + 70);
    
    // Stop sending any forces - don't process further
    return;
  }

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
