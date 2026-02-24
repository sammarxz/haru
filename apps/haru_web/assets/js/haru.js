/**
 * Haru Analytics tracking snippet
 * < 2kb minified. No dependencies. IIFE.
 *
 * Usage:
 *   <script defer src="/js/haru.js"
 *           data-token="YOUR_SITE_TOKEN"
 *           data-api="https://yourharu.com"></script>
 */
(function () {
  "use strict";

  var script = document.currentScript || (function () {
    var scripts = document.getElementsByTagName("script");
    return scripts[scripts.length - 1];
  })();

  var token = script && script.getAttribute("data-token");
  var apiBase = (script && script.getAttribute("data-api")) || "";

  if (!token) {
    console.warn("[Haru] Missing data-token attribute.");
    return;
  }

  var startTime = Date.now();

  /**
   * Infers a two-letter country code from the browser locale.
   * e.g. "pt-BR" -> "BR", "en-US" -> "US", "fr" -> null
   * Not a substitute for server-side IP geolocation, but covers the common case
   * without any external dependency or privacy-sensitive data.
   */
  function getCountryCode() {
    try {
      var locale = navigator.language || "";
      var parts = locale.split("-");
      if (parts.length >= 2) {
        return parts[parts.length - 1].toUpperCase();
      }
    } catch (_) {}
    return null;
  }

  function sendEvent(path, extra) {
    var country = getCountryCode();
    var base = {
      p: path || window.location.pathname,
      r: document.referrer || "",
      sw: window.screen.width,
      sh: window.screen.height,
      n: "pageview"
    };
    if (country) base.c = country;

    var payload = JSON.stringify(Object.assign(base, extra || {}));

    // Token is passed as query param because sendBeacon does not support custom headers
    var url = apiBase + "/api/collect?t=" + encodeURIComponent(token);

    if (typeof navigator.sendBeacon === "function") {
      var blob = new Blob([payload], { type: "application/json" });
      navigator.sendBeacon(url, blob);
    } else {
      var xhr = new XMLHttpRequest();
      xhr.open("POST", url, true);
      xhr.setRequestHeader("Content-Type", "application/json");
      xhr.send(payload);
    }
  }

  function sendDuration() {
    var ms = Date.now() - startTime;
    if (ms < 500) return; // ignore instant bounces
    var url = apiBase + "/api/collect?t=" + encodeURIComponent(token);
    var payload = JSON.stringify({
      p: window.location.pathname,
      n: "duration",
      d: ms
    });
    if (typeof navigator.sendBeacon === "function") {
      navigator.sendBeacon(url, new Blob([payload], { type: "application/json" }));
    }
  }

  // Track duration on page hide
  document.addEventListener("visibilitychange", function () {
    if (document.visibilityState === "hidden") {
      sendDuration();
    }
  });

  // Initial pageview
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () { sendEvent(); });
  } else {
    sendEvent();
  }

  // SPA support: hook pushState + popstate
  var pushState = history.pushState;
  history.pushState = function () {
    pushState.apply(history, arguments);
    startTime = Date.now();
    sendEvent(arguments[2]);
  };

  window.addEventListener("popstate", function () {
    startTime = Date.now();
    sendEvent(window.location.pathname);
  });
})();
