(() => {
  const replacements = new Map([
    ["No events for today!", "No releases today"],
  ]);

  const previewFields = new Map([
    ["Plex Activity", ["streams", "user"]],
    ["Requests", ["pending", "approved", "completed"]],
    ["qBittorrent", ["leech", "download", "seed", "upload"]],
    ["SABnzbd", ["rate", "queue", "time left"]],
    ["Autobrr", ["approved", "rejected", "filters", "indexers"]],
    ["Radarr", ["wanted", "missing", "queued"]],
    ["Sonarr", ["wanted", "queued", "series"]],
    ["Prowlarr", ["grabs", "queries", "fail grabs", "fail queries"]],
    ["UniFi", ["wan", "lan users", "wlan users", "uptime"]],
    ["Gatus", ["sites up", "sites down", "uptime"]],
  ]);

  const isLocalPreview = ["127.0.0.1", "localhost"].includes(window.location.hostname);

  function serviceName(card) {
    const heading = card.querySelector(".service-name");
    const text = heading?.textContent?.trim() ?? "";

    for (const name of previewFields.keys()) {
      if (text.startsWith(name)) {
        return name;
      }
    }

    return null;
  }

  function addPreviewPlaceholders(root) {
    if (!isLocalPreview) return;

    for (const card of root.querySelectorAll?.(".service-card") ?? []) {
      const name = serviceName(card);

      if (!name || card.querySelector(".service-block, .hp-preview-grid")) {
        continue;
      }

      const title = card.querySelector(".service-title");
      if (!title) continue;

      const grid = document.createElement("div");
      grid.className = "hp-preview-grid";
      grid.setAttribute("aria-label", "Preview stat placeholders");

      for (const label of previewFields.get(name)) {
        const block = document.createElement("div");
        block.className = "service-block hp-preview-block";

        const value = document.createElement("span");
        value.textContent = "-";

        const caption = document.createElement("span");
        caption.textContent = label.toUpperCase();

        block.append(value, caption);
        grid.append(block);
      }

      title.insertAdjacentElement("afterend", grid);
    }
  }

  function replaceText(root) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    const nodes = [];

    while (walker.nextNode()) {
      nodes.push(walker.currentNode);
    }

    for (const node of nodes) {
      const trimmed = node.nodeValue.trim();
      const replacement = replacements.get(trimmed);

      if (replacement) {
        node.nodeValue = node.nodeValue.replace(trimmed, replacement);
      }
    }
  }

  function init() {
    replaceText(document.body);
    addPreviewPlaceholders(document.body);

    new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === "characterData") {
          const trimmed = mutation.target.nodeValue.trim();
          const replacement = replacements.get(trimmed);

          if (replacement) {
            mutation.target.nodeValue = mutation.target.nodeValue.replace(trimmed, replacement);
          }
        }

        for (const node of mutation.addedNodes) {
          if (node.nodeType === Node.TEXT_NODE) {
            const trimmed = node.nodeValue.trim();
            const replacement = replacements.get(trimmed);

            if (replacement) {
              node.nodeValue = node.nodeValue.replace(trimmed, replacement);
            }
          } else if (node.nodeType === Node.ELEMENT_NODE) {
            replaceText(node);
            addPreviewPlaceholders(node);
          }
        }
      }
    }).observe(document.body, {
      characterData: true,
      childList: true,
      subtree: true,
    });

    const interval = window.setInterval(() => {
      replaceText(document.body);
      addPreviewPlaceholders(document.body);
    }, 1000);
    window.setTimeout(() => window.clearInterval(interval), 30000);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
