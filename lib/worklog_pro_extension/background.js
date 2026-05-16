/**
 * WorkLog Pro - Background Script (Hybrid Idle Detection)
 * 
 * PRIMARY: Per-site idle detection via content script heartbeat pulses.
 *   - Only pulses from the TRACKED TAB reset the heartbeat.
 *   - If no pulse for 5 minutes → session is paused (idle_stopped).
 * 
 * FALLBACK: chrome.idle API (system-wide).
 *   - Catches screen lock / user completely away from computer.
 *   - Fires immediately when OS reports idle/locked state.
 * 
 * This script MUST load local Firebase files to work in Manifest V3.
 */

importScripts('firebase-app.js');
importScripts('firebase-auth.js');
importScripts('firebase-firestore.js');

const firebaseConfig = {
  apiKey: "AIzaSyB22WOsZNeM3VN9WKyPCDG8eVElUBmUnMA",
  authDomain: "nexxgenva-2d149.firebaseapp.com",
  projectId: "nexxgenva-2d149",
  storageBucket: "nexxgenva-2d149.firebasestorage.app",
  messagingSenderId: "188575575343",
  appId: "1:188575575343:web:87b2a91665994c9f3805da",
  measurementId: "G-TJHKJ2NEZQ"
};

try {
  firebase.initializeApp(firebaseConfig);
} catch (e) {
  console.log("Firebase already initialized");
}

const db = firebase.firestore();
const auth = firebase.auth();
const APP_ID = "clock-in-app-v1";

// ─── Persistent State Keys ──────────────────────────────────────────────────
const KEY_ACTIVE_LOG_ID = "activeLogId";
const KEY_TARGET_SITE = "targetSite";
const KEY_TARGET_TAB_ID = "targetTabId";
const KEY_LAST_HEARTBEAT = "lastHeartbeat";
const KEY_LAST_DB_UPDATE = "lastDbUpdate";

// ─── Configuration ──────────────────────────────────────────────────────────
const IDLE_THRESHOLD_MS = 15 * 60 * 1000;     // 15 minutes — allows time for redirected tasks on viral mailer sites
const IDLE_THRESHOLD_SECONDS = 900;            // 15 minutes for chrome.idle API
const HEARTBEAT_CHECK_INTERVAL_MIN = 1;        // Check every 1 minute

let currentUserId = null;
let lastSnapshotDocs = [];

// ─── chrome.idle Setup (FALLBACK - system-wide) ─────────────────────────────
// This catches screen lock and total inactivity (no mouse/keyboard anywhere).
chrome.idle.setDetectionInterval(IDLE_THRESHOLD_SECONDS);

chrome.idle.onStateChanged.addListener(async (newState) => {
  console.log(`[WorkLog] chrome.idle state → ${newState}`);

  const result = await chrome.storage.local.get([KEY_ACTIVE_LOG_ID, KEY_TARGET_SITE]);
  if (!result[KEY_ACTIVE_LOG_ID] || !result[KEY_TARGET_SITE]) return;

  if (newState === "idle" || newState === "locked") {
    console.log(`[WorkLog] FALLBACK: User ${newState}. Ending session.`);
    await endSession(result[KEY_ACTIVE_LOG_ID], "idle_stopped");
  }
  // Note: We do NOT refresh heartbeat on "active" here.
  // Only actual content script pulses from the tracked tab should do that.
});

// ─── Auth Listener ──────────────────────────────────────────────────────────
auth.onAuthStateChanged((user) => {
  if (user) {
    currentUserId = user.uid;
    listenForActiveSession();
  } else {
    auth.signInAnonymously().catch(console.error);
  }
});

// ─── ALARMS ─────────────────────────────────────────────────────────────────
chrome.alarms.create("heartbeatCheck", { periodInMinutes: HEARTBEAT_CHECK_INTERVAL_MIN });
chrome.alarms.create("screenshotCapture", { periodInMinutes: 1 });

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === "heartbeatCheck") {
    await checkIdleState();
  } else if (alarm.name === "screenshotCapture") {
    await captureScreenshot();
  }
});

// ─── Service Worker Restart Recovery ────────────────────────────────────────
// MV3 SWs can restart. Recover active session alarms on startup.
chrome.storage.local.get([KEY_ACTIVE_LOG_ID], (result) => {
  if (result[KEY_ACTIVE_LOG_ID]) {
    console.log("[WorkLog] SW restarted with active session. Re-creating alarms.");
    startHeartbeatCheck();
  }
});

// ─── Screenshot Capture ─────────────────────────────────────────────────────
async function captureScreenshot() {
  const result = await chrome.storage.local.get([KEY_ACTIVE_LOG_ID, KEY_TARGET_TAB_ID]);
  const { activeLogId, targetTabId } = result;

  if (!activeLogId || !targetTabId) return;

  try {
    let tab;
    try {
      tab = await chrome.tabs.get(targetTabId);
    } catch (e) {
      console.log("[WorkLog] Screenshot skipped: Tab not found.");
      return;
    }

    if (!tab.active) {
      console.log("[WorkLog] Tracking tab is not active, skipping screenshot.");
      return;
    }

    const dataUrl = await chrome.tabs.captureVisibleTab(tab.windowId, {
      format: "jpeg",
      quality: 20
    });

    await db.collection('artifacts')
      .doc(APP_ID)
      .collection('public')
      .doc('data')
      .collection('logs')
      .doc(activeLogId)
      .collection('screenshots')
      .add({
        imageUrl: dataUrl,
        timestamp: firebase.firestore.FieldValue.serverTimestamp()
      });

    console.log("[WorkLog] Screenshot captured and saved.");
  } catch (error) {
    console.error("[WorkLog] Screenshot failed:", error);
  }
}

// ─── PRIMARY: Per-Site Idle Check (runs every 1 minute via alarm) ───────────
// Checks if content script on the TRACKED TAB has sent a pulse recently.
// If no pulse for 5 minutes → user is idle on that site → end session.
async function checkIdleState() {
  const result = await chrome.storage.local.get([
    KEY_LAST_HEARTBEAT, KEY_ACTIVE_LOG_ID, KEY_TARGET_SITE, KEY_TARGET_TAB_ID
  ]);
  const { lastHeartbeat, activeLogId, targetSite, targetTabId } = result;

  if (!activeLogId || !targetSite) return;

  // 1. Tab Existence Check
  // NOTE: We no longer end the session if the tracked tab navigates away.
  // Viral mailer workflows involve redirects to other sites — this is expected.
  // We only end the session if the user is truly system-idle (chrome.idle handles that).
  if (targetTabId) {
    try {
      const tab = await chrome.tabs.get(targetTabId);
      if (tab.url && !tab.url.toLowerCase().includes(targetSite)) {
        // Tab has navigated away — this is normal for viral mailer redirects.
        // Just log it, do NOT end the session.
        console.log("[WorkLog] Tracked tab navigated away (redirect in progress):", tab.url);
      }
    } catch (e) {
      // Tab was closed — session ends.
      console.log("[WorkLog] Target tab closed. Ending session.");
      await endSession(activeLogId, "tab_closed");
      return;
    }
  } else {
    // No tab ID stored yet — try to find the original site tab.
    const tabs = await chrome.tabs.query({});
    const match = tabs.find(t => t.url && t.url.toLowerCase().includes(targetSite));
    if (match) {
      console.log("[WorkLog] Found original tab, updating ID:", match.id);
      await chrome.storage.local.set({ [KEY_TARGET_TAB_ID]: match.id });
    }
    // If not found, it may have navigated away — don't end session, rely on system idle.
  }

  // 2. Per-site heartbeat check
  const now = Date.now();
  const lastHb = lastHeartbeat || now;
  const diffMs = now - lastHb;
  const diffSec = Math.round(diffMs / 1000);

  console.log(`[WorkLog] Per-site idle check: ${diffSec}s since last pulse from tracked tab.`);

  if (diffMs >= IDLE_THRESHOLD_MS) {
    console.log("[WorkLog] PRIMARY: No activity on tracked site for 5+ min. Stopping session.");
    await endSession(activeLogId, "idle_stopped");
  }
}

// ─── End Session ────────────────────────────────────────────────────────────
async function endSession(logId, reason) {
  // Guard: check if session is still active to avoid duplicate end calls
  const check = await chrome.storage.local.get([KEY_ACTIVE_LOG_ID]);
  if (check[KEY_ACTIVE_LOG_ID] !== logId) {
    console.log("[WorkLog] Session already ended or mismatch. Skipping.");
    return;
  }

  console.log(`[WorkLog] Ending session ${logId} due to: ${reason}`);

  // Clear local state FIRST to prevent duplicate endSession calls
  await chrome.storage.local.remove([
    KEY_ACTIVE_LOG_ID, KEY_TARGET_SITE, KEY_TARGET_TAB_ID,
    KEY_LAST_HEARTBEAT, KEY_LAST_DB_UPDATE
  ]);
  chrome.action.setBadgeText({ text: "" });
  stopHeartbeatCheck();

  // Then update Firestore
  try {
    await db.collection('artifacts')
      .doc(APP_ID)
      .collection('public')
      .doc('data')
      .collection('logs')
      .doc(logId)
      .update({
        status: reason === 'idle_stopped' ? 'idle_stopped' : 'completed',
        endTime: firebase.firestore.FieldValue.serverTimestamp()
      });
    console.log("[WorkLog] Firestore updated successfully.");
  } catch (e) {
    console.error("[WorkLog] Error updating Firestore:", e);
  }
}

// ─── Alarm Management ───────────────────────────────────────────────────────
function startHeartbeatCheck() {
  chrome.alarms.create("heartbeatCheck", { periodInMinutes: HEARTBEAT_CHECK_INTERVAL_MIN });
}

function stopHeartbeatCheck() {
  chrome.alarms.clear("heartbeatCheck");
}

// ─── Listen for Active Sessions in Firestore ────────────────────────────────
function listenForActiveSession() {
  const logsPath = db.collection('artifacts')
    .doc(APP_ID)
    .collection('public')
    .doc('data')
    .collection('logs');

  logsPath
    .where('status', '==', 'active')
    .onSnapshot(async (snapshot) => {
      lastSnapshotDocs = snapshot.docs;
      const localState = await chrome.storage.local.get([KEY_ACTIVE_LOG_ID]);
      let activeLogId = localState[KEY_ACTIVE_LOG_ID];

      if (snapshot.empty) {
        if (activeLogId) {
          console.log("[WorkLog] No active logs in DB. Resetting local.");
          await chrome.storage.local.remove([
            KEY_ACTIVE_LOG_ID, KEY_TARGET_SITE, KEY_TARGET_TAB_ID,
            KEY_LAST_HEARTBEAT, KEY_LAST_DB_UPDATE
          ]);
          chrome.action.setBadgeText({ text: "" });
          stopHeartbeatCheck();
        }
        return;
      }

      chrome.tabs.query({}, (tabs) => {
        for (const doc of snapshot.docs) {
          const data = doc.data();
          const siteUrl = data.site ? data.site.toLowerCase().trim() : "";
          if (!siteUrl) continue;

          const matchedTab = tabs.find(t => t.url && t.url.toLowerCase().includes(siteUrl));

          if (matchedTab) {
            console.log("[WorkLog] Matched active session!", doc.id, siteUrl);

            chrome.storage.local.set({
              [KEY_ACTIVE_LOG_ID]: doc.id,
              [KEY_TARGET_SITE]: siteUrl,
              [KEY_TARGET_TAB_ID]: matchedTab.id,
              [KEY_LAST_HEARTBEAT]: Date.now()
            });

            startHeartbeatCheck();
            chrome.action.setBadgeText({ text: "WORK" });
            chrome.action.setBadgeBackgroundColor({ color: "#4CAF50" });
            break;
          }
        }
      });
    });
}

// ─── Tab Monitoring ─────────────────────────────────────────────────────────
chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' && tab.url) {
    const result = await chrome.storage.local.get([
      KEY_TARGET_SITE, KEY_TARGET_TAB_ID, KEY_ACTIVE_LOG_ID
    ]);
    const targetSite = result[KEY_TARGET_SITE];
    const storedTabId = result[KEY_TARGET_TAB_ID];
    const activeLogId = result[KEY_ACTIVE_LOG_ID];

    if (targetSite && tab.url.toLowerCase().includes(targetSite)) {
      if (storedTabId !== tabId) {
        chrome.storage.local.set({ [KEY_TARGET_TAB_ID]: tabId });
      }
      chrome.action.setBadgeText({ text: "WORK" });
      chrome.action.setBadgeBackgroundColor({ color: "#4CAF50" });
    }
    else if (!activeLogId && lastSnapshotDocs.length > 0) {
      for (const doc of lastSnapshotDocs) {
        const data = doc.data();
        const siteUrl = data.site ? data.site.toLowerCase().trim() : "";
        if (siteUrl && tab.url.toLowerCase().includes(siteUrl)) {
          console.log("[WorkLog] Matched session on tab update!", doc.id, siteUrl);
          chrome.storage.local.set({
            [KEY_ACTIVE_LOG_ID]: doc.id,
            [KEY_TARGET_SITE]: siteUrl,
            [KEY_TARGET_TAB_ID]: tabId,
            [KEY_LAST_HEARTBEAT]: Date.now()
          });
          startHeartbeatCheck();
          chrome.action.setBadgeText({ text: "WORK" });
          chrome.action.setBadgeBackgroundColor({ color: "#4CAF50" });
          break;
        }
      }
    }
  }
});

// ─── Tab Closure ────────────────────────────────────────────────────────────
chrome.tabs.onRemoved.addListener((tabId, removeInfo) => {
  chrome.storage.local.get([KEY_TARGET_TAB_ID, KEY_ACTIVE_LOG_ID], function (result) {
    if (result[KEY_TARGET_TAB_ID] === tabId && result[KEY_ACTIVE_LOG_ID]) {
      console.log("[WorkLog] Tracked tab closed.");
      endSession(result[KEY_ACTIVE_LOG_ID], "tab_closed");
    }
  });
});

// ─── Message Handling (Activity Pulses) ─────────────────────────────────────
// Activity pulses are accepted from ANY tab.
// Viral mailer workflows redirect users to other sites — activity on those tabs
// is still valid work activity and should keep the session alive.
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (!message || !message.type) return;

  if (message.type === 'USER_ACTIVITY_PULSE') {
    chrome.storage.local.get([KEY_ACTIVE_LOG_ID], (result) => {
      const activeLogId = result[KEY_ACTIVE_LOG_ID];

      if (!activeLogId) return;

      // Accept pulses from ANY tab — user is actively working (possibly on a redirected site)
      if (sender.tab) {
        chrome.storage.local.set({ [KEY_LAST_HEARTBEAT]: Date.now() });

        // Throttled Firestore update (once every 2 minutes)
        chrome.storage.local.get([KEY_LAST_DB_UPDATE], (dbResult) => {
          const lastDbUpdate = dbResult[KEY_LAST_DB_UPDATE] || 0;
          const now = Date.now();
          if (now - lastDbUpdate > 2 * 60 * 1000) {
            db.collection('artifacts')
              .doc(APP_ID)
              .collection('public')
              .doc('data')
              .collection('logs')
              .doc(activeLogId)
              .update({
                lastActive: firebase.firestore.FieldValue.serverTimestamp()
              })
              .then(() => chrome.storage.local.set({ [KEY_LAST_DB_UPDATE]: now }))
              .catch(err => console.error("[WorkLog] Pulse DB update failed:", err));
          }
        });
      }
    });

    sendResponse({ status: 'ok' });
  }

  if (message.type === 'START_TRACK' && message.site) {
    if (!currentUserId) auth.signInAnonymously().catch(console.error);
    sendResponse({ status: 'Tracking initiated via App logic' });
  }
  return true;
});
