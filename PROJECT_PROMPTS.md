# Project Prompts: Haptic Lathe

This document contains a compilation of user prompts and objectives from the current and previous sessions relevant to the Haptic Lathe project.

## Current Session: Refining Material Stiffness & Code Cleanup
**Date:** Dec 13, 2025

1.  **Objective:** Refining Material Stiffness
    *   *Context:* Adjusting material properties for the virtual lathe simulation (`k_wall`, Yield Force) and adding 'Inconel'.
2.  "Comment out all the printing commands."
3.  "How is the vibration amplitude being calculated? Is it actually being rendered?"
4.  "WHy is the free spinning gone? bring back the motor control from d8097d7b6e8c95639239d7db0af67803ca7056b3"
5.  "Make the up and down arrow keys control the spindle speed"
6.  "Change inconel stiffness to 2x 6061 then push to github"
7.  "Why does it cut through the middle suddnely whithout actually reachign the midpoitn when cutting radially"
8.  "Push to github"
9.  "Remove AI code slop"
    *   *Details:* "remove all AI generated slop introduced in this codebase. This includes: Extra comments... Extra defensive checks... Casts to any... Inconsistent style... Orphaned functions..."
10. "Clean up the gui file too"
11. "Push to github"
12. "Make the code we just commited the main branch"
13. "Put all prompts used in this project into a markdown file across all relevant chats"

## Previous Session: Refine Lathe Haptics and Controls
**Date:** Dec 04, 2025

1.  **Objective:** Refine Lathe Haptics and Controls
    *   *Goals:*
        *   Implement "Crash" behavior (0 RPM contact).
        *   Reverse control direction for Z-axis (axial) and X-axis (radial).
        *   Update force reaction direction to match new controls.

## Session: Damping Feedback Experiments
**Date:** Dec 03, 2025

1.  "Implement Damping Haptic Feedback"
    *   *Context:* Replacing virtual wall with velocity-based damping.
2.  "There was NO force rendered at all" / "Fundamental issue with pico communication"
3.  "Revert to the last main commit"
4.  "remove all haptic feedback from current code, implement damping as feedback... Damping force should be around 50n maximum. Make a plan and wait for my approval"
5.  "change the current spring constant to 0.2x the current value"
6.  "Add the prompts from this chat to the project prompts file"

## Previous Session: Fixing Haptic Feedback
**Date:** Dec 02, 2025

1.  **Objective:** Fixing Haptic Feedback
    *   *Goals:*
        *   Fix axial haptic feedback (prevent "reset to start" bug).
        *   Ensure correct behavior for "Reset Workpiece" button.
        *   Diagnose and resolve axial feedback issues.
