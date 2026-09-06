/**
 * Phase page initializer — call initPhase(config) from each phase HTML
 */
function initPhase(config) {
  const { id, checklist, criteria, prompts, passThreshold = 70 } = config;

  document.addEventListener("DOMContentLoaded", () => {
    const params = new URLSearchParams(window.location.search);
    const channel = params.get("channel");

    setActiveChannel(channel);

    localStorage.setItem(
      configStorageKey(id),
      JSON.stringify({ criteria, passThreshold })
    );

    initChecklist(id, checklist);
    initScoring(id, criteria);
    initFeedback(id);
    if (prompts) initPromptRotator(prompts);

    const totalEl = document.getElementById("total-score");
    if (totalEl) totalEl.dataset.pass = passThreshold;

    if (channel) {
      const badge = document.getElementById("channel-badge");
      if (badge) {
        const names = { drone: "Drone Technology", military: "Military Bases", family: "Family" };
        badge.textContent = names[channel] || channel;
        badge.style.display = "inline-block";
      }
    }

    const prev = document.getElementById("nav-prev");
    const next = document.getElementById("nav-next");
    if (prev && config.prev) prev.href = appendChannelParam(config.prev, channel);
    if (next && config.next) next.href = appendChannelParam(config.next, channel);
  });
}
