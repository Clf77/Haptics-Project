// ==================== LatheState.pde ====================
// Holds training scenario, skill level, stock dimensions, and cutting params.

class LatheState {
  // stock dimensions in inches
  float stockLengthIn   = 9.0;
  float stockDiameterIn = 1.25;
  float pxPerIn         = 60.0;
  
  // ===== STOCK CUT PROFILE (radius vs Z) =====
  int profileSamples = 200;      // number of slices along Z
  float[] radiusProfileIn = null; // radius (in inches) at each slice
  float baseStockDiameterIn = -1;
  float baseStockLengthIn   = -1;


  // training scenario flags
  boolean facingSelected       = false;
  boolean turnDiaSelected      = false;
  boolean boringSelected       = false;
  boolean customSelected       = false;

  // skill level
  boolean beginnerSelected     = false;
  boolean intermediateSelected = false;
  boolean advancedSelected     = false;

  // cutting parameters
  float spindleRPM = 0;
  float feedRate   = 0;
  float depthCut   = 0;

  LatheState() {
    facingSelected   = true;
    beginnerSelected = true;
  }

  String getScenario() {
    boolean any = facingSelected || turnDiaSelected || boringSelected || customSelected;
    if (facingSelected || !any) return "facing";
    if (turnDiaSelected)        return "turn";
    if (boringSelected)         return "boring";
    return "custom";
  }

  boolean anySkill() {
    return (beginnerSelected || intermediateSelected || advancedSelected);
  }

  String getSkillLevel() {
    if (beginnerSelected)     return "beginner";
    if (intermediateSelected) return "intermediate";
    if (advancedSelected)     return "advanced";
    return "beginner";
  }

  String getToleranceString() {
    if (!anySkill() || beginnerSelected) {
      return "± 0.010 in";
    } else if (intermediateSelected) {
      return "± 0.005 in";
    } else {
      return "± 0.002 in";
    }
  }

  void selectScenario(String s) {
    facingSelected   = false;
    turnDiaSelected  = false;
    boringSelected   = false;
    customSelected   = false;

    if (s.equals("facing")) {
      facingSelected = true;
    } else if (s.equals("turn")) {
      turnDiaSelected = true;
    } else if (s.equals("boring")) {
      boringSelected = true;
    } else {
      customSelected = true;
    }
  }

  void selectSkill(String s) {
    beginnerSelected     = false;
    intermediateSelected = false;
    advancedSelected     = false;

    if (s.equals("beginner")) {
      beginnerSelected = true;
    } else if (s.equals("intermediate")) {
      intermediateSelected = true;
    } else if (s.equals("advanced")) {
      advancedSelected = true;
    }
  }

  String lastScenario = "";

  void updateStockFromScenario() {
    String scenario = getScenario();
    
    // Only update if scenario changed
    if (!scenario.equals(lastScenario)) {
      if (scenario.equals("facing")) {
        stockDiameterIn = 1.25;
        stockLengthIn   = 4.50;
      } else if (scenario.equals("turn")) {
        stockDiameterIn = 1.25;
        stockLengthIn   = 4.00;
      } else if (scenario.equals("boring")) {
        stockDiameterIn = 2.00;
        stockLengthIn   = 3.00;
      } else {
        stockDiameterIn = 1.50;
        stockLengthIn   = 4.00;
      }
      
      // Initialize the profile whenever stock changes
      initProfile();
      lastScenario = scenario;
    }
  }

  void initProfile() {
    // Higher resolution for smoother cutting
    profileSamples = 400; 
    radiusProfileIn = new float[profileSamples];
    float initialRadius = stockDiameterIn / 2.0;
    
    // Fill profile with initial stock radius
    for (int i = 0; i < profileSamples; i++) {
      radiusProfileIn[i] = initialRadius;
    }
    
    // For boring, we might want to start with a hole, but for now solid stock or pre-drilled logic
    if (boringSelected) {
       // Pre-drill for boring
       float holeRadius = 0.75 / 2.0; // 0.75 inch hole
       for (int i = 0; i < profileSamples; i++) {
         // Simple pre-drill entire length
         // In reality, boring might be blind, but let's assume through hole for simplicity or partial
         radiusProfileIn[i] = initialRadius; 
       }
       // Note: Boring usually cuts from inside out. 
       // For simplicity, we'll track the "outer" surface for turning and "inner" for boring?
       // Let's stick to outer turning for now to keep it simple, or just track "material boundary".
       // For a simple lathe sim, usually we track the outer radius.
    }
  }

  // Helper to map Z position (inches from chuck face) to profile index
  int getProfileIndex(float zDistFromChuckIn) {
    if (zDistFromChuckIn < 0 || zDistFromChuckIn > stockLengthIn) return -1;
    return int(map(zDistFromChuckIn, 0, stockLengthIn, 0, profileSamples - 1));
  }

  // Get radius at specific Z
  float getRadiusAt(float zDistFromChuckIn) {
    int idx = getProfileIndex(zDistFromChuckIn);
    if (idx >= 0 && idx < profileSamples) {
      return radiusProfileIn[idx];
    }
    return 0;
  }

  // Cut material at specific Z to new radius
  void cutAt(float zDistFromChuckIn, float newRadiusIn) {
    int idx = getProfileIndex(zDistFromChuckIn);
    if (idx >= 0 && idx < profileSamples) {
      // Only cut if we are removing material (new radius < current radius)
      if (newRadiusIn < radiusProfileIn[idx]) {
        radiusProfileIn[idx] = newRadiusIn;
      }
    }
  }
}
