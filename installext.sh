#!/bin/bash

# Updated shell script to create the Chrome/Chromium extension with additional features: strict mode for aggressive hiding/blocking, more cosmetic selectors from EasyList/uBlock, integrated uBlock Origin-style filters, hiding cookie popups, footers, comments, share buttons, promoted content, overriding popups in strict mode, and console logging for potential issues.
# Run this on Debian-based Linux (e.g., via curl -sSL <pastebin-url> | bash)
# It creates/updates the folder ~/dupe-tab-closer with all necessary files.
# Then, in Chromium/Chrome, go to chrome://extensions/, enable Developer mode, and click "Load unpacked" to select ~/dupe-tab-closer.

EXTENSION_DIR="$HOME/dupe-tab-closer"

mkdir -p "$EXTENSION_DIR"
cd "$EXTENSION_DIR" || exit 1

# manifest.json remains the same
cat <<EOF > manifest.json
{
  "manifest_version": 3,
  "name": "Duplicate Tab Closer",
  "version": "1.6",
  "description": "Closes duplicate tabs automatically, clears cache, unloads inactive tabs, adblocking with optimized EasyList/uBlock-inspired rules and cosmetic filters, strict mode, and more.",
  "permissions": [
    "tabs",
    "storage",
    "browsingData",
    "alarms",
    "declarativeNetRequest",
    "declarativeNetRequestFeedback"
  ],
  "host_permissions": ["<all_urls>"],
  "background": {
    "service_worker": "background.js"
  },
  "action": {
    "default_popup": "popup.html"
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["content.js"],
      "run_at": "document_start"
    }
  ],
  "declarative_net_request": {
    "rule_resources": [
      {
        "id": "ruleset_1",
        "enabled": true,
        "path": "rules.json"
      }
    ]
  }
}
EOF

# background.js remains the same
cat <<EOF > background.js
// Setup default settings on install
chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.sync.set({
    autoClose: true,
    periodicCheck: false,
    interval: 5,
    matchFull: true,
    unloadInactive: true,
    cacheTimer: true,
    cacheSeconds: 30,
    strictMode: false,
    patterns: []
  });
});

// Setup alarms on startup and settings change
chrome.runtime.onStartup.addListener(setupAlarms);
chrome.storage.onChanged.addListener((changes) => {
  if (changes.periodicCheck || changes.interval) {
    setupAlarms();
  }
});

async function setupAlarms() {
  const data = await chrome.storage.sync.get(['periodicCheck', 'interval']);
  chrome.alarms.clear('checkDuplicates');
  if (data.periodicCheck) {
    chrome.alarms.create('checkDuplicates', { periodInMinutes: data.interval || 5 });
  }
}

// Periodic check
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'checkDuplicates') {
    checkDuplicates();
  }
});

// Auto close on creation
chrome.tabs.onCreated.addListener(async (tab) => {
  const data = await chrome.storage.sync.get('autoClose');
  if (data.autoClose) {
    checkDuplicates();
  }
});

// Track last active tab for cache timer and unload
let lastActiveTabId = null;

// Unload inactive tabs and handle cache timer on activation
chrome.tabs.onActivated.addListener(async (info) => {
  const data = await chrome.storage.sync.get(['unloadInactive', 'cacheTimer', 'cacheSeconds']);
  
  if (lastActiveTabId !== null && lastActiveTabId !== info.tabId) {
    // Handle previous tab
    chrome.tabs.get(lastActiveTabId, (prevTab) => {
      if (chrome.runtime.lastError || !prevTab || !prevTab.url.startsWith('http')) return;
      
      const origin = new URL(prevTab.url).origin;
      
      if (data.unloadInactive && !prevTab.discarded) {
        chrome.tabs.discard(prevTab.id);
      }
      
      if (data.cacheTimer) {
        const seconds = (data.cacheSeconds || 30) * 1000;
        setTimeout(() => {
          chrome.browsingData.remove({ origins: [origin] }, { cache: true }, () => {
            console.log('Cache cleared for origin:', origin);
          });
        }, seconds);
      }
    });
  }
  
  lastActiveTabId = info.tabId;
  
  // Unload all other tabs if unloadInactive
  if (data.unloadInactive) {
    const tabs = await chrome.tabs.query({});
    for (let t of tabs) {
      if (t.id !== info.tabId && !t.discarded && t.url.startsWith('http')) {
        chrome.tabs.discard(t.id);
      }
    }
  }
});

// Initialize lastActiveTabId on startup
async function initLastActive() {
  const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
  if (tabs.length > 0) {
    lastActiveTabId = tabs[0].id;
  }
}
initLastActive();

// Check and close duplicates/patterns
async function checkDuplicates() {
  const data = await chrome.storage.sync.get(['matchFull', 'patterns']);
  const tabs = await chrome.tabs.query({});
  const urlToId = new Map();
  for (let tab of tabs) {
    if (!tab.url || !tab.url.startsWith('http')) continue;
    let shouldClose = false;
    const url = tab.url;

    // Check patterns (always, for auto-close like /ads/)
    for (let pat of data.patterns || []) {
      try {
        if (new RegExp(pat).test(url)) {
          shouldClose = true;
          break;
        }
      } catch (e) {
        console.error('Invalid pattern:', pat);
      }
    }

    // Check duplicates if matchFull enabled
    if (!shouldClose && data.matchFull) {
      if (urlToId.has(url)) {
        shouldClose = true;
      } else {
        urlToId.set(url, tab.id);
      }
    }

    if (shouldClose) {
      chrome.tabs.remove(tab.id);
    }
  }
}

// Handle messages from popup
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.action === 'closeDuplicates') {
    checkDuplicates();
  }
});
EOF

# Update popup.html with strictMode checkbox
cat <<EOF > popup.html
<!DOCTYPE html>
<html>
<head>
  <title>Duplicate Tab Closer Settings</title>
  <style>
    body { font-family: Arial, sans-serif; padding: 10px; width: 300px; }
    h1, h2, h3 { margin: 10px 0 5px; }
    label { display: block; margin: 5px 0; }
    button { margin: 5px 0; }
    ul { list-style: none; padding: 0; }
    li { margin: 5px 0; }
  </style>
</head>
<body>
  <h1>Duplicate Tab Closer</h1>
  <button id="closeDuplicates">Close Duplicates Now</button>
  <button id="clearCache">Clear Cache Now</button>
  <h2>Settings</h2>
  <label><input type="checkbox" id="autoClose">Auto close on creation</label>
  <label><input type="checkbox" id="periodicCheck">Periodic check</label>
  <label>Interval (mins): <input type="number" id="interval" min="1"></label>
  <label><input type="checkbox" id="matchFull">Match full URL for duplicates</label>
  <label><input type="checkbox" id="unloadInactive">Unload inactive tabs (like offline mode, no background loading)</label>
  <label><input type="checkbox" id="cacheTimer">Clear cache for inactive tabs after seconds</label>
  <label>Cache clear seconds: <input type="number" id="cacheSeconds" min="1"></label>
  <label><input type="checkbox" id="strictMode">Strict Mode (aggressive ad/popup blocking, may break sites)</label>
  <h3>Custom Close Patterns (e.g., /ads/)</h3>
  <input type="text" id="newPattern" placeholder="Pattern (regex)">
  <button id="addPattern">Add Pattern</button>
  <ul id="patternsList"></ul>
  <script src="popup.js"></script>
</body>
</html>
EOF

# Update popup.js with strictMode
cat <<EOF > popup.js
document.addEventListener('DOMContentLoaded', () => {
  chrome.storage.sync.get(['autoClose', 'periodicCheck', 'interval', 'matchFull', 'unloadInactive', 'cacheTimer', 'cacheSeconds', 'strictMode', 'patterns'], (data) => {
    document.getElementById('autoClose').checked = data.autoClose !== false;
    document.getElementById('periodicCheck').checked = !!data.periodicCheck;
    document.getElementById('interval').value = data.interval || 5;
    document.getElementById('matchFull').checked = data.matchFull !== false;
    document.getElementById('unloadInactive').checked = data.unloadInactive !== false;
    document.getElementById('cacheTimer').checked = data.cacheTimer !== false;
    document.getElementById('cacheSeconds').value = data.cacheSeconds || 30;
    document.getElementById('strictMode').checked = !!data.strictMode;
    updatePatternsList(data.patterns || []);
  });

  // Save changes
  document.getElementById('autoClose').addEventListener('change', (e) => chrome.storage.sync.set({autoClose: e.target.checked}));
  document.getElementById('periodicCheck').addEventListener('change', (e) => chrome.storage.sync.set({periodicCheck: e.target.checked}));
  document.getElementById('interval').addEventListener('change', (e) => chrome.storage.sync.set({interval: parseInt(e.target.value)}));
  document.getElementById('matchFull').addEventListener('change', (e) => chrome.storage.sync.set({matchFull: e.target.checked}));
  document.getElementById('unloadInactive').addEventListener('change', (e) => chrome.storage.sync.set({unloadInactive: e.target.checked}));
  document.getElementById('cacheTimer').addEventListener('change', (e) => chrome.storage.sync.set({cacheTimer: e.target.checked}));
  document.getElementById('cacheSeconds').addEventListener('change', (e) => chrome.storage.sync.set({cacheSeconds: parseInt(e.target.value)}));
  document.getElementById('strictMode').addEventListener('change', (e) => chrome.storage.sync.set({strictMode: e.target.checked}));

  // Add pattern
  document.getElementById('addPattern').addEventListener('click', () => {
    const pat = document.getElementById('newPattern').value.trim();
    if (!pat) return;
    chrome.storage.sync.get('patterns', (data) => {
      const patterns = data.patterns || [];
      patterns.push(pat);
      chrome.storage.sync.set({patterns});
      updatePatternsList(patterns);
      document.getElementById('newPattern').value = '';
    });
  });

  // Close duplicates
  document.getElementById('closeDuplicates').addEventListener('click', () => {
    chrome.runtime.sendMessage({action: 'closeDuplicates'});
  });

  // Clear cache
  document.getElementById('clearCache').addEventListener('click', () => {
    chrome.browsingData.remove({}, {cache: true}, () => {
      alert('Cache cleared!');
    });
  });

  function updatePatternsList(patterns) {
    const list = document.getElementById('patternsList');
    list.innerHTML = '';
    patterns.forEach((pat, index) => {
      const li = document.createElement('li');
      li.textContent = pat;
      const removeBtn = document.createElement('button');
      removeBtn.textContent = 'Remove';
      removeBtn.onclick = () => {
        patterns.splice(index, 1);
        chrome.storage.sync.set({patterns});
        updatePatternsList(patterns);
      };
      li.appendChild(removeBtn);
      list.appendChild(li);
    });
  }
});
EOF

# Update content.js with strictMode, more cosmetic selectors, popup blocking, etc.
cat <<EOF > content.js
// Optimized hiding of ads/promoted elements with extended EasyList/uBlock-inspired cosmetic filters
const cosmeticSelectors = [
  '.ad', 'div[id^="ad_"]', '.ad-banner', '.ad-container', '.ad-wrapper', '.ad-slot', '.ad-unit', '.ad-zone', '.ad-block', '.ad-popup',
  '.ad-iframe', '.ad-img', '.ad-link', '.ad-text', '.ad-rectangle', '.ad-script', '.ad-overlay', '.ad-side', '.ad-top', '.ad_side',
  '.ad_text_', '.ad_top_3', '.admarket', '.adshow', '.adsense', '.adverts', '.adv', '.advertisement', '.advertisers', '.ad_api',
  '.ad_server', '.ad_tool', '.ad_widget', '.banner', '.banner_ad', '.bnr_ad_', '.crossuse_top_ad', '.discovery_recommend', '.gampad_ads',
  '.googleAdSense', '.img_ad', '.openx', '.popin_discovery', '.prebid', '.prebid8', '.vcushion', '.videojs-contrib-ads', '.yads', '.yads-timeline-ex',
  '.yads-async', '.adpopup', '.adsninja_client', '.adsninja', '.ad_detect', '.ad_api_popunder', '.ad_native', '.ad_preferences', '.ad_sdk', '.ad_tag',
  '.ad_impl', '.ad_frame', '.ad_wrapper', '.ad_blocker', '.ad_counter', '.ad_redirect', '.ad_iframe', '.ad_script', '.ad_image', '.ad_div',
  '.google-ads-responsive', '.google-ads-right', '.google-ads-sidebar', '.google-ads-widget', '.google-ads-wrapper', '.google-adsense', '.google-advert-sidebar',
  '.google-afc-wrapper', '.google-bottom-ads', '.google-dfp-ad-caption', '.google-dfp-ad-wrapper', '.google-right-ad', '.google-sponsored', '.google-sponsored-ads',
  '.google-sponsored-link', '.google-sponsored-links', '.google468', '.googleAd', '.googleAdBox', '.googleAdContainer', '.googleAdSearch', '.googleAdSense',
  '.googleAdWrapper', '.googleAdd', '.googleAds', '.googleAdsContainer', '.googleAdsense', '.googleAdv', '.google_ad', '.google_ad_container', '.google_ad_label',
  '.google_ad_wide', '.google_add', '.google_admanager', '.google_ads', '.google_ads_content', '.google_ads_sidebar', '.google_adsense', '.google_adsense1',
  '.google_adsense_footer', '.google_afc', '.google_afc_ad', '.googlead', '.googleadArea', '.googleadbottom', '.googleadcontainer', '.googleaddiv', '.googleads',
  '.googleads-container', '.googleads-height', '.googleadsense', '.googleadsrectangle', '.googleadv', '.googleadvertisement', '.googleadwrap', '.googleafc',
  '.gpAds', '.gpt-ad', '.gpt-ad-container', '.gpt-ad-sidebar-wrap', '.gpt-ad-wrapper', '.gpt-ads', '.gpt-billboard', '.gpt-breaker-container', '.gpt-container',
  '.gpt-leaderboard-banner', '.gpt-mpu-banner', '.gpt-sticky-sidebar', '.gpt.top-slot', '.gptSlot', '.gptSlot-outerContainer', '.gptSlot__sticky-footer', '.gptslot',
  // Additional from EasyList/uBlock: cookies, popups, footers, comments, shares, promoted
  '.cookie-banner', '.cookie-consent', '.cookie-notice', '.consent-banner', '.cookie-popup', '.gdpr-cookie', '.cookie-policy', '.cookie-consent-banner',
  '.popup', '.modal-popup', '.overlay-popup', '.pop-up-window', '.popup-ad', '.modal-ad', '.lightbox-popup', '.exit-popup', '.popup-container', '.modal-window', '.pop-under',
  '.footer', '.site-footer', '.page-footer', '.footer-ad', '.footer-widget', '.bottom-footer', '.footer-section', '.footer-links', '.footer-copyright', '.footer-ad-space', '.footer-promoted', '.footer-sponsor',
  '.comment-section', '.comments-area', '.comment-box', '.comment-form', '.comments-container', '.comment-thread', '.comment-list', '.comment-input', '.user-comments', '.comment-area', '.comment-widget',
  '.share-button', '.share-buttons', '.share-widget', '.share-panel', '.social-share', '.social-buttons', '.social-icons', '.share-options', '.social-media', '.social-links', '.social-feed', '.social-media-bar',
  '.promoted-content', '.sponsored', '.sponsored-content', '.promoted-ad', '.advertorial', '.sponsored-ad', '.promoted-section', '.sponsored-section', '.advertisement', '.advertising', '.sponsored-links', '.promoted-post',
  '.social-media-element', '.social-widget', '.social-feed', '.social-icons', '.social-share-buttons', '.social-media-icons', '.social-media-links',
  // More aggressive for strict mode: logos, junk, etc.
  '.sponsored-logo', '.promoted-logo', '.ad-logo', '.junk-code', '.spam-element', '.tracking-pixel', '.beacon'
];

const hostname = location.hostname;

// Prepare CSS selectors
let cssSelectors = [...cosmeticSelectors];

if (hostname.includes('youtube.com')) {
  cssSelectors.push('ytd-promoted-video-renderer', 'ytd-in-feed-ad-layout-renderer', 'ytd-ad-slot-renderer', '.ytd-companion-slot-renderer');
}

if (hostname.includes('twitter.com') || hostname.includes('x.com')) {
  cssSelectors.push('[data-testid="placementTracking"]', '[data-testid="promotedTweet"]', '.promoted');
}

// Inject CSS for general and simple site-specific hiding
if (cssSelectors.length > 0) {
  const style = document.createElement('style');
  style.textContent = cssSelectors.join(', ') + ' { display: none !important; }';
  (document.head || document.documentElement).appendChild(style);
}

// For complex hiding requiring JS (Facebook, Instagram) and strict mode features
chrome.storage.sync.get('strictMode', (data) => {
  const strictMode = data.strictMode;
  
  if (strictMode) {
    console.warn('Strict Mode enabled: Aggressive blocking applied. If the site breaks, disable in extension popup and reload.');
    // Override window.open to block popups
    window.open = function() {
      console.log('Blocked popup attempt');
      return null;
    };
    // Additional strict hiding or removal (e.g., remove comment scripts, but since cosmetic, already hidden)
  }

  const needsJsHiding = hostname.includes('facebook.com') || hostname.includes('instagram.com') || strictMode;

  if (needsJsHiding) {
    function hideElements() {
      if (hostname.includes('facebook.com')) {
        document.querySelectorAll('span:has(> a[aria-label="Sponsored"]), .sponsored_ad').forEach(el => {
          const post = el.closest('div[data-pagelet]');
          if (post) {
            post.style.display = 'none';
            if (strictMode) console.log('Hid sponsored post on Facebook');
          }
        });
      }

      if (hostname.includes('instagram.com')) {
        document.querySelectorAll('article[role="presentation"] > div[style*="max-height: inherit; max-width: inherit;"]').forEach(el => {
          const span = el.querySelector('span');
          if (span && span.textContent.match(/Anzeige|Gesponsert|Sponsored|Geborg|Sponzorováno|Sponsoreret|Χορηγούμενη|Publicidad|Sponsoroitu|Sponsorisé|Bersponsor|Sponsorizzato|広告|광고|Ditaja|Sponset|Gesponsord|Sponsorowane|Patrocinado|Реклама|Sponsrad|ได้รับการสนับสนุน|May Sponsor|Sponsorlu|赞助内容|贊助|প্রযোজিত|પ્રાયોજિત|स्पॉन्सर्ड|Sponzorirano|ಪ್ರಾಯೋಜಿತ|സ്‌പോൺസർ ചെയ്‌തത്|पुरस्‍कृत|प्रायोजित|ਪ੍ਰਾਯੋਜਿਤ|මුදල් ගෙවා ප්‍රචාරය කරන ලදි|Sponzorované|விளம்பரதாரர்கள்|స్పాన్సర్ చేసింది|Được tài trợ|Спонсорирано|Commandité|Sponsorizat|Спонзорисано/)) {
            el.style.display = 'none !important';
            if (strictMode) console.log('Hid sponsored post on Instagram');
          }
        });
      }

      if (strictMode) {
        // Additional strict mode hiding for comments, footers, etc. (already in CSS, but log)
        document.querySelectorAll('.comment-section, footer, .share-buttons').forEach(el => {
          console.log('Strict mode hid element:', el.className || el.id);
        });
      }
    }

    // Debounced hide for performance
    let scheduled = false;
    function debouncedHide() {
      if (scheduled) return;
      scheduled = true;
      requestAnimationFrame(() => {
        hideElements();
        scheduled = false;
      });
    }

    // Initial hide and observer setup
    if (document.readyState === 'complete' || document.readyState === 'interactive') {
      hideElements();
      const observer = new MutationObserver(debouncedHide);
      observer.observe(document.body, { childList: true, subtree: true });
    } else {
      document.addEventListener('DOMContentLoaded', () => {
        hideElements();
        const observer = new MutationObserver(debouncedHide);
        observer.observe(document.body, { childList: true, subtree: true });
      });
    }
  }
});
EOF

# Update rules.json with more uBlock Origin-inspired network filters
cat <<EOF > rules.json
[
  {
    "id": 1,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||doubleclick.net^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 2,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||googleadservices.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 3,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||adservice.google.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 4,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||googlesyndication.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 5,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||googletagservices.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 6,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||facebook.net^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  {
    "id": 7,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||facebook.com^$script,third-party", "resourceTypes": ["script"] }
  },
  {
    "id": 8,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||google-analytics.com^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  {
    "id": 9,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||analytics.google.com^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  {
    "id": 10,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||scorecardresearch.com^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  {
    "id": 11,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||adnxs.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 12,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||openx.net^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 13,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||pubmatic.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 14,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||rubiconproject.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 15,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||casalemedia.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 16,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||advertising.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 17,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||yieldmanager.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 18,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||popads.net^", "resourceTypes": ["sub_frame", "script"] }
  },
  {
    "id": 19,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||popcash.net^", "resourceTypes": ["sub_frame", "script"] }
  },
  {
    "id": 20,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||tracking.^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  {
    "id": 21,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||criteo.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 22,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||taboola.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 23,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||outbrain.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 24,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||revcontent.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 25,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||mgid.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 26,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||quantserve.com^", "resourceTypes": ["script", "xmlhttprequest", "image"] }
  },
  {
    "id": 27,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||chartbeat.com^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  {
    "id": 28,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||amazon-adsystem.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 29,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||moatads.com^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  {
    "id": 30,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||adform.net^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 31,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||smartadserver.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 32,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||contextual.media.net^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 33,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||bidswitch.net^", "resourceTypes": ["xmlhttprequest"] }
  },
  {
    "id": 34,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||serving-sys.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 35,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||adsafeprotected.com^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  {
    "id": 36,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||teads.tv^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 37,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||adroll.com^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  {
    "id": 38,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||sharethrough.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 39,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||kargo.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 40,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||lijit.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 41,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||districtm.io^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 42,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||gumgum.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 43,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||33across.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 44,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||sonobi.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 45,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||rhythmone.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 46,
    "priority": 1,
    "action": {
      "type": "modifyHeaders",
      "responseHeaders": [{ "header": "cache-control", "operation": "set", "value": "no-cache" }]
    },
    "condition": { "resourceTypes": ["image", "media"] }
  },
  {
    "id": 47,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "/ads/", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 48,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "/adserver/", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 49,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "/banner/", "resourceTypes": ["image"] }
  },
  {
    "id": 50,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||adsymptotic.com^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  // Additional uBlock Origin-inspired filters
  {
    "id": 51,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||adition.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 52,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||adserver.google.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 53,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||imasdk.googleapis.com^", "resourceTypes": ["script"] }
  },
  {
    "id": 54,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||adlib.*^", "resourceTypes": ["script"] }
  },
  {
    "id": 55,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||tag.aticdn.net^", "resourceTypes": ["script"] }
  },
  {
    "id": 56,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||chartbeat.com^", "resourceTypes": ["script"] }
  },
  {
    "id": 57,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||tags.crwdcntrl.net^", "resourceTypes": ["script"] }
  },
  {
    "id": 58,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||acdn.adnxs.com^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  {
    "id": 59,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||adtech.de^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 60,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||onetag-sys.com^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  {
    "id": 61,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||2mdn.net^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 62,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||googleads.g.doubleclick.net^", "resourceTypes": ["script"] }
  },
  {
    "id": 63,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||fundingchoicesmessages.google.com^", "resourceTypes": ["script"] }
  },
  {
    "id": 64,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||clk.sh^", "resourceTypes": ["sub_frame"] }
  },
  {
    "id": 65,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||short.pe^", "resourceTypes": ["sub_frame"] }
  },
  {
    "id": 66,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||perfotrack.com^", "resourceTypes": ["script", "xmlhttprequest"] }
  },
  {
    "id": 67,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||adsloboclick.com^", "resourceTypes": ["sub_frame", "script"] }
  },
  {
    "id": 68,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||exosrv.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  },
  {
    "id": 69,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||ads-twitter.com^", "resourceTypes": ["script"] }
  },
  {
    "id": 70,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||ads.exoclick.com^", "resourceTypes": ["image", "script", "xmlhttprequest", "sub_frame"] }
  }
]
EOF

echo "Extension updated in $EXTENSION_DIR with strict mode, more cosmetic selectors, uBlock Origin filters integration, and additional hiding/blocking features."