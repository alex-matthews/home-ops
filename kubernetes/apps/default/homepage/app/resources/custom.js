(() => {
  const replacements = new Map([
    ["No events for today!", "No releases today"],
  ]);

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
          }
        }
      }
    }).observe(document.body, {
      characterData: true,
      childList: true,
      subtree: true,
    });

    const interval = window.setInterval(() => replaceText(document.body), 1000);
    window.setTimeout(() => window.clearInterval(interval), 30000);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
