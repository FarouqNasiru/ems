/**
 * WorkLog Pro - Activity Sensor
 * This script runs on every page the user visits to detect if the user is physically present.
 */

let lastReportTime = Date.now();

/**
 * Sends a message to the background script to signal that the user is active.
 * We use throttling to ensure we don't spam the background worker.
 */
function reportActivity() {
  const now = Date.now();

  // Throttle messages to the background script to once every 30 seconds
  // This saves CPU resources and avoids unnecessary database pings.
  if (now - lastReportTime > 30000) {
    lastReportTime = now;

    try {
      // Send a pulse to the background script
      chrome.runtime.sendMessage({
        type: "USER_ACTIVITY_PULSE",
        timestamp: now
      });
      // console.log("WorkLog Pro: Activity pulse sent to background.");
    } catch (e) {
      // The extension context might be invalidated if the extension was reloaded
      // or the background script is currently inactive.
    }
  }
}

// Low-level event listeners to detect various forms of user interaction
// 'passive: true' is used to improve scrolling performance.
document.addEventListener('mousemove', reportActivity, { passive: true });
document.addEventListener('keydown', reportActivity, { passive: true });
document.addEventListener('scroll', reportActivity, { passive: true });
document.addEventListener('mousedown', reportActivity, { passive: true });
document.addEventListener('touchstart', reportActivity, { passive: true });

console.log("WorkLog Pro: Activity monitoring injected successfully.");