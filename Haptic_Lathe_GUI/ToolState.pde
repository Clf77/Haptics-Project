// ==================== ToolState.pde ====================
// Holds tool tip position, X/Z zeroing offsets, and collision logic.

class ToolState {
  // tool tip position in pixels
  float toolTipXpx = 0;
  float toolTipYpx = 0;

  // raw positions in inches
  float rawXIn = 0;  // radial
  float rawZIn = 0;  // axial

  // zero offsets
  float xZeroOffsetIn = 0;
  float zZeroOffsetIn = 0;

  // displayed positions
  float xPosIn = 0;
  float zPosIn = 0;

  // collision
  boolean collision = false;
  float collisionForce = 0.0;

  ToolState() {
  }

  // Hook for future model-only updates (currently geometry is set in drawMainView)
  void updatePosition(LatheState lathe, Bridge bridge, boolean usePhysicalInput, String activeAxis) {
    // Intentionally minimal for now.
  }

  // full collision detection and haptic logic
  // full collision detection and haptic logic
  void updateCollision(LatheState lathe,
                       Bridge bridge,
                       float chuckX,
                       float stockRightX,
                       float centerY,
                       float stockRadiusPx) {
    boolean wasColliding = collision;
    collision = false;
    float maxPenetration = 0;

    // Tool properties
    float tipWidthPx = 12.0; 
    float tipWidthIn = tipWidthPx / lathe.pxPerIn;
    
    // We check a few points along the tool tip width to cut material
    // The tool tip is centered at rawZIn. 
    // Let's iterate from left edge to right edge of the tool insert.
    float startZ = rawZIn - tipWidthIn / 2.0;
    float endZ   = rawZIn + tipWidthIn / 2.0;
    
    // Step size for cutting checks (small enough to hit profile samples)
    float stepZ = (lathe.stockLengthIn / lathe.profileSamples) * 0.5; 
    
    for (float z = startZ; z <= endZ; z += stepZ) {
      if (z < 0 || z > lathe.stockLengthIn) continue;
      
      float currentStockRadius = lathe.getRadiusAt(z);
      float toolRadius = rawXIn; // Tool tip radial position
      
      // Check for collision/cutting
      // For turning, we cut if tool is closer to center than surface
      if (toolRadius < currentStockRadius) {
        collision = true;
        
        // Calculate penetration for this point
        float pen = currentStockRadius - toolRadius;
        if (pen > maxPenetration) maxPenetration = pen;
        
        // CUT THE MATERIAL
        lathe.cutAt(z, toolRadius);
      }
    }

    if (collision) {
      // simple linear mapping to a 0–100 "force" scale
      // Using max penetration found across the tool width
      collisionForce = map(maxPenetration, 0, 0.1, 0, 100); // 0.1 inch cut is max force
      collisionForce = constrain(collisionForce, 0, 100);

      // send / update haptic feedback
      if (bridge.connected) {
        bridge.sendHapticFeedback(collisionForce, true);
      }
    } else {
      collisionForce = 0.0;

      // only send a "clear" message when we *leave* collision
      if (bridge.connected && wasColliding) {
        bridge.sendHapticFeedback(0, false);
      }
    }
  }
}
