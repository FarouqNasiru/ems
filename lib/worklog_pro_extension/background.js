/**
 * WorkLog Pro - Fixed Background Script
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

// Persistent State Keys
const KEY_ACTIVE_LOG_ID = "activeLogId";
const KEY_TARGET_SITE = "targetSite";
const KEY_TARGET_TAB_ID = "targetTabId";
const KEY_LAST_HEARTBEAT = "lastHeartbeat";

let currentUserId = null;
let lastSnapshotDocs = []; // Store active sessions to re-check on tab updates

// Auth Listener
auth.onAuthStateChanged((user) => {
  if (user) {
    currentUserId = user.uid;
    listenForActiveSession();
  } else {
    auth.signInAnonymously().catch(console.error);
  }
});

// --- 3. ALARMS (Heartbeat & Screenshots) ---
chrome.alarms.create("heartbeatCheck", { periodInMinutes: 1 });
chrome.alarms.create("screenshotCapture", { periodInMinutes: 1 });

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === "heartbeatCheck") {
    checkIdleState();
  } else if (alarm.name === "screenshotCapture") {
    captureScreenshot();
  }
});

async function captureScreenshot() {
  const result = await chrome.storage.local.get(['activeLogId', 'targetSite', 'targetTabId']);
  const { activeLogId, targetTabId } = result;

  if (!activeLogId || !targetTabId) return;

  try {
    // verifying tab is still there
    let tab;
    try {
      tab = await chrome.tabs.get(targetTabId);
    } catch (e) {
      console.log("Screenshot skipped: Tab not found.");
      return;
    }

    if (!tab.active) {
      console.log("Tracking tab is not active, skipping screenshot.");
      return;
    }

    const dataUrl = await chrome.tabs.captureVisibleTab(tab.windowId, {
      format: "jpeg",
      quality: 20 // Low quality to ensure < 1MB for Firestore
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

    console.log("Screenshot captured and saved.");

  } catch (error) {
    console.error("Screenshot failed:", error);
    if (error && error.message && error.message.includes("active tab")) {
      console.log("Skipping screenshot: Target tab is not active.");
    }
  }
}

function checkIdleState() {
  chrome.storage.local.get([KEY_LAST_HEARTBEAT, KEY_ACTIVE_LOG_ID, KEY_TARGET_SITE, KEY_TARGET_TAB_ID], async (result) => {
    const { lastHeartbeat, activeLogId, targetSite, targetTabId } = result;

    if (!activeLogId || !targetSite) {
      return;
    }

    // 1. Robust Existence Check
    if (targetTabId) {
      try {
        const tab = await chrome.tabs.get(targetTabId);
        if (!tab.url || !tab.url.toLowerCase().includes(targetSite)) {
          console.log("Tab exists but URL mismatch. Considered closed/navigated.", tab.url);
          await endSession(activeLogId, "tab_closed_or_navigated");
          return;
        }
      } catch (e) {
        console.log("Target tab not found (closed). Ending session.");
        await endSession(activeLogId, "tab_closed");
        return;
      }
    } else {
      // Fallback: Scan all tabs
      const tabs = await chrome.tabs.query({});
      const match = tabs.find(t => t.url && t.url.toLowerCase().includes(targetSite));
      if (!match) {
        console.log("No tabs found matching site. Ending session.");
        await endSession(activeLogId, "site_not_found");
        return;
      } else {
        console.log("Found lost tab, updating ID:", match.id);
        chrome.storage.local.set({ [KEY_TARGET_TAB_ID]: match.id });
      }
    }

    // 2. Idle Check
    const now = Date.now();
    const diff = now - (lastHeartbeat || now);

    // 4 minutes 55 seconds (Ensures trigger on first alarm after 5 mins)
    if (diff > 295 * 1000) {
      console.log("Idle detected. Stopping session.");
      await endSession(activeLogId, "idle_stopped");
    }
  });
}

async function endSession(logId, reason) {
  console.log(`Ending session ${logId} due to: ${reason}`);
  try {
    await db.collection('artifacts').doc(APP_ID).collection('public').doc('data').collection('logs').doc(logId).update({
      status: reason === 'idle_stopped' ? 'idle_stopped' : 'completed',
      endTime: firebase.firestore.FieldValue.serverTimestamp()
    });

    // Notification removed per user request

  } catch (e) {
    console.error("Error ending session:", e);
  }

  await chrome.storage.local.remove([KEY_ACTIVE_LOG_ID, KEY_TARGET_SITE, KEY_TARGET_TAB_ID, KEY_LAST_HEARTBEAT]);
  chrome.action.setBadgeText({ text: "" });
  stopHeartbeatCheck();
}

function startHeartbeatCheck() {
  chrome.alarms.create("heartbeatCheck", { periodInMinutes: 1 });
}

function stopHeartbeatCheck() {
  chrome.alarms.clear("heartbeatCheck");
}

function listenForActiveSession() {
  const logsPath = db.collection('artifacts').doc(APP_ID).collection('public').doc('data').collection('logs');

  logsPath
    .where('status', '==', 'active')
    .onSnapshot(async (snapshot) => {
      lastSnapshotDocs = snapshot.docs; // Keep for onUpdated fallback
      const localState = await chrome.storage.local.get([KEY_ACTIVE_LOG_ID]);
      let activeLogId = localState[KEY_ACTIVE_LOG_ID];

      if (snapshot.empty) {
        if (activeLogId) {
          console.log("No active logs found in DB. Resetting local.");
          await chrome.storage.local.remove([KEY_ACTIVE_LOG_ID, KEY_TARGET_SITE, KEY_TARGET_TAB_ID, KEY_LAST_HEARTBEAT]);
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
            console.log("Found matching active session!", doc.id, siteUrl);

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

// Tab Monitoring
chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' && tab.url) {
    const result = await chrome.storage.local.get([KEY_TARGET_SITE, KEY_TARGET_TAB_ID, KEY_ACTIVE_LOG_ID]);
    const targetSite = result[KEY_TARGET_SITE];
    const storedTabId = result[KEY_TARGET_TAB_ID];
    const activeLogId = result[KEY_ACTIVE_LOG_ID];

    // If we have an active session, update tab ID if it changed
    if (targetSite && tab.url.toLowerCase().includes(targetSite)) {
      if (storedTabId !== tabId) {
        chrome.storage.local.set({ [KEY_TARGET_TAB_ID]: tabId });
      }
      chrome.action.setBadgeText({ text: "WORK" });
      chrome.action.setBadgeBackgroundColor({ color: "#4CAF50" });
    }
    // If NO active session is tracked locally, check if this new tab matches any active session from DB
    else if (!activeLogId && lastSnapshotDocs.length > 0) {
      for (const doc of lastSnapshotDocs) {
        const data = doc.data();
        const siteUrl = data.site ? data.site.toLowerCase().trim() : "";
        if (siteUrl && tab.url.toLowerCase().includes(siteUrl)) {
          console.log("Found matching session on tab update!", doc.id, siteUrl);
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

// Tab Closure - Immediate Check
chrome.tabs.onRemoved.addListener((tabId, removeInfo) => {
  chrome.storage.local.get([KEY_TARGET_TAB_ID, KEY_ACTIVE_LOG_ID], function (result) {
    if (result[KEY_TARGET_TAB_ID] === tabId && result[KEY_ACTIVE_LOG_ID]) {
      console.log("Tab Remove Event Detected for tracked tab.");
      endSession(result[KEY_ACTIVE_LOG_ID], "tab_closed");
    }
  });
});

// Message Handling
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (!message || !message.type) return;

  if (message.type === 'USER_ACTIVITY_PULSE') {
    // Only update heartbeat if the activity comes from the TRACKED TAB
    chrome.storage.local.get([KEY_TARGET_TAB_ID, KEY_ACTIVE_LOG_ID], (result) => {
      const targetTabId = result[KEY_TARGET_TAB_ID];

      // Check if message sender matches target tab
      if (sender.tab && sender.tab.id === targetTabId) {
        chrome.storage.local.set({ [KEY_LAST_HEARTBEAT]: Date.now() });

        // Update 'lastActive' in Firestore occasionally (Throttled to once every 2 minutes to reduce network noise)
        if (result[KEY_ACTIVE_LOG_ID]) {
          const lastDbUpdate = result['lastDbUpdate'] || 0;
          const now = Date.now();
          if (now - lastDbUpdate > 2 * 60 * 1000) {
            db.collection('artifacts').doc(APP_ID).collection('public').doc('data').collection('logs')
              .doc(result[KEY_ACTIVE_LOG_ID]).update({
                lastActive: firebase.firestore.FieldValue.serverTimestamp()
              })
              .then(() => chrome.storage.local.set({ 'lastDbUpdate': now }))
              .catch(err => console.error("Pulse DB update failed:", err));
          }
        }
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
