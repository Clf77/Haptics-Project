// ==================== Bridge.pde ====================
// Handles file-based communication with the Python motor/haptics controller.

import java.io.File;

class Bridge {
  String statusPath;
  String commandPath;
  boolean connected = false;

  JSONObject lastStatus;
  float handlePosition = 0.0;
  boolean emergencyStop = false;

  long lastHeartbeat = 0;
  int  heartbeatInterval = 1000;  // ms

  Bridge() {
  }

  void initPaths(String statusFile, String commandsFile) {
    statusPath  = statusFile;
    commandPath = commandsFile;
  }

  void checkConnection() {
    try {
      File f = new File(statusPath);
      connected = f.exists();
    } catch (Exception e) {
      connected = false;
    }
  }

  void sendRaw(String msg) {
    if (!connected) return;
    try {
      String[] lines = { msg };
      saveStrings(commandPath, lines);
      println("Sent to bridge: " + msg);
    } catch (Exception e) {
      println("Error sending to bridge: " + e.getMessage());
    }
  }

  void pollStatus(LatheState lathe, ToolState tool) {
    if (!connected) return;
    try {
      File f = new File(statusPath);
      if (!f.exists()) return;

      String[] lines = loadStrings(statusPath);
      if (lines == null || lines.length == 0) return;

      String data = join(lines, "");
      lastStatus = parseJSONObject(data);
      if (lastStatus == null) return;

      String msgType = lastStatus.getString("type", "");

      if (msgType.equals("status_update")) {
        handlePosition = lastStatus.getFloat("handle_wheel_position", 0.0);
        emergencyStop  = lastStatus.getBoolean("emergency_stop", false);
        lastHeartbeat  = millis();
      }
    } catch (Exception e) {
      // ignore corrupt / partial reads
    }
  }

  // convenience wrappers
  void sendModeChange(String mode, String skill) {
    JSONObject o = new JSONObject();
    o.setString("type", "mode_change");
    o.setString("mode", mode);
    o.setString("skill_level", skill);
    sendRaw(o.toString());
  }

  void sendReset() {
    JSONObject o = new JSONObject();
    o.setString("type", "reset");
    sendRaw(o.toString());
  }

  void sendZero(String axis) {
    JSONObject o = new JSONObject();
    o.setString("type", "zero_position");
    o.setString("axis", axis);
    sendRaw(o.toString());
  }

  void updateCuttingParameters(float spindleRPM, float feedRate) {
    JSONObject o = new JSONObject();
    o.setString("type", "set_parameters");
    o.setFloat("spindle_rpm", spindleRPM);
    o.setFloat("feed_rate",  feedRate);
    sendRaw(o.toString());
  }

  void sendEmergencyStop() {
    JSONObject o = new JSONObject();
    o.setString("type", "emergency_stop");
    sendRaw(o.toString());
  }

  void sendHapticFeedback(float force, boolean active) {
    JSONObject o = new JSONObject();
    o.setString("type", "haptic_feedback");
    o.setFloat("force", force);
    o.setBoolean("active", active);
    sendRaw(o.toString());
  }

  void sendMotorControl(String action, float value) {
    JSONObject o = new JSONObject();
    o.setString("type", "motor_control");
    o.setString("action", action);
    o.setFloat("value", value);
    sendRaw(o.toString());
  }

  void sendAxisSelect(String axis) {
    JSONObject o = new JSONObject();
    o.setString("type", "axis_select");
    o.setString("axis", axis);
    sendRaw(o.toString());
  }
}
