/**
 * YouTube Pipeline Platform — shared tracking, scoring, feedback
 */

const STORAGE_PREFIX = "yt-pipeline-";

function storageKey(id) {
  return STORAGE_PREFIX + id;
}

function loadState(id) {
  try {
    const raw = localStorage.getItem(storageKey(id));
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function saveState(id, data) {
  localStorage.setItem(storageKey(id), JSON.stringify(data));
}

function defaultPhaseState(phaseId) {
  return {
    phaseId,
    checklist: {},
    scores: {},
    feedback: [],
    updatedAt: new Date().toISOString(),
  };
}

function getPhaseState(phaseId) {
  return loadState(phaseId) || defaultPhaseState(phaseId);
}

function initChecklist(phaseId, items) {
  const state = getPhaseState(phaseId);
  const list = document.getElementById("checklist");
  if (!list) return;

  list.innerHTML = "";
  items.forEach((item, i) => {
    const key = `item-${i}`;
    const li = document.createElement("li");
    const checked = state.checklist[key] || false;
    if (checked) li.classList.add("done");

    li.innerHTML = `
      <input type="checkbox" id="${key}" ${checked ? "checked" : ""} data-key="${key}">
      <label for="${key}">${item}</label>
    `;
    list.appendChild(li);

    li.querySelector("input").addEventListener("change", (e) => {
      state.checklist[e.target.dataset.key] = e.target.checked;
      li.classList.toggle("done", e.target.checked);
      state.updatedAt = new Date().toISOString();
      saveState(phaseId, state);
      updateChecklistProgress(phaseId, items.length);
    });
  });

  updateChecklistProgress(phaseId, items.length);
}

function updateChecklistProgress(phaseId, total) {
  const state = getPhaseState(phaseId);
  const done = Object.values(state.checklist).filter(Boolean).length;
  const el = document.getElementById("checklist-progress");
  if (el) el.textContent = `${done} / ${total} complete`;
}

function initScoring(phaseId, criteria) {
  const state = getPhaseState(phaseId);
  const grid = document.getElementById("score-grid");
  if (!grid) return;

  grid.innerHTML = "";
  criteria.forEach((c) => {
    const div = document.createElement("div");
    div.className = "score-item";
    const val = state.scores[c.id] ?? "";
    div.innerHTML = `
      <label for="score-${c.id}">${c.label} (max ${c.max})</label>
      <input type="number" id="score-${c.id}" min="0" max="${c.max}" value="${val}" placeholder="0–${c.max}">
    `;
    grid.appendChild(div);

    div.querySelector("input").addEventListener("input", (e) => {
      let v = parseInt(e.target.value, 10);
      if (isNaN(v)) v = 0;
      v = Math.min(c.max, Math.max(0, v));
      state.scores[c.id] = v;
      state.updatedAt = new Date().toISOString();
      saveState(phaseId, state);
      updateTotalScore(phaseId, criteria);
    });
  });

  updateTotalScore(phaseId, criteria);
}

function updateTotalScore(phaseId, criteria) {
  const state = getPhaseState(phaseId);
  const maxTotal = criteria.reduce((s, c) => s + c.max, 0);
  let total = 0;
  criteria.forEach((c) => {
    total += state.scores[c.id] || 0;
  });

  const pct = maxTotal > 0 ? Math.round((total / maxTotal) * 100) : 0;
  const el = document.getElementById("total-score");
  if (!el) return;

  const passThreshold = parseInt(el.dataset.pass || "70", 10);
  el.className = "total-score";
  if (pct >= passThreshold) el.classList.add("pass");
  else if (pct > 0) el.classList.add("fail");
  else el.classList.add("pending");

  const valueEl = el.querySelector(".value");
  const labelEl = el.querySelector(".label");
  if (valueEl) valueEl.textContent = `${pct}%`;
  if (labelEl) {
    labelEl.textContent =
      pct >= passThreshold
        ? "PASS — Meets criteria"
        : pct > 0
          ? "FAIL — Edit & resubmit"
          : "PENDING — Awaiting scores";
  }

  const badge = document.getElementById("grade-badge");
  if (badge) {
    badge.textContent = pct >= passThreshold ? "PASS" : pct > 0 ? "FAIL" : "PENDING";
    badge.className = "grade-badge " + (pct >= passThreshold ? "grade-pass" : pct > 0 ? "grade-fail" : "grade-pending");
  }
}

function initFeedback(phaseId) {
  const state = getPhaseState(phaseId);
  renderFeedback(phaseId);

  const form = document.getElementById("feedback-form");
  if (!form) return;

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const author = form.querySelector('[name="author"]').value.trim() || "Team Member";
    const text = form.querySelector('[name="comment"]').value.trim();
    if (!text) return;

    state.feedback.unshift({
      author,
      text,
      time: new Date().toISOString(),
    });
    state.updatedAt = new Date().toISOString();
    saveState(phaseId, state);
    form.reset();
    renderFeedback(phaseId);
  });
}

function renderFeedback(phaseId) {
  const state = getPhaseState(phaseId);
  const list = document.getElementById("feedback-list");
  if (!list) return;

  if (state.feedback.length === 0) {
    list.innerHTML = '<p class="text-muted text-small">No feedback yet. Be the first to comment.</p>';
    return;
  }

  list.innerHTML = state.feedback
    .map(
      (f) => `
    <div class="feedback-item">
      <div class="meta">${f.author} · ${formatTime(f.time)}</div>
      <div>${escapeHtml(f.text)}</div>
    </div>`
    )
    .join("");
}

function formatTime(iso) {
  const d = new Date(iso);
  return d.toLocaleString();
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

function initPromptRotator(prompts, intervalMs = 8000) {
  const box = document.getElementById("prompt-rotator");
  if (!box || !prompts.length) return;

  let idx = 0;
  box.textContent = prompts[0];

  setInterval(() => {
    idx = (idx + 1) % prompts.length;
    box.style.opacity = "0";
    setTimeout(() => {
      box.textContent = prompts[idx];
      box.style.opacity = "1";
    }, 300);
  }, intervalMs);
}

function getAllPhaseGrades() {
  const phases = [
    "phase-01-trends",
    "phase-02-automation",
    "phase-03-avatar",
    "phase-04-strategy",
    "phase-05-ai-review",
    "phase-06-mission-control",
    "phase-07-analytics",
    "phase-08-week-one",
    "phase-09-tracking",
  ];

  return phases.map((id) => {
    const state = loadState(id);
    const configRaw = localStorage.getItem("yt-pipeline-config-" + id);
    const config = configRaw ? JSON.parse(configRaw) : null;
    
    if (!state || !state.scores) return { id, grade: null, pct: 0 };
    
    let total = 0;
    let max = 0;
    
    if (config && config.criteria) {
      config.criteria.forEach(c => {
        total += state.scores[c.id] || 0;
        max += c.max || 10;
      });
    } else {
      total = Object.values(state.scores).reduce((s, v) => s + (v || 0), 0);
      max = Object.keys(state.scores).length * 10;
    }
    
    const passThreshold = config ? config.passThreshold : 70;
    const pct = max > 0 ? Math.round((total / max) * 100) : 0;
    return {
      id,
      grade: pct >= passThreshold ? "PASS" : pct > 0 ? "FAIL" : "PENDING",
      pct,
      updatedAt: state.updatedAt,
    };
  });
}

function renderDashboard() {
  const tbody = document.getElementById("pipeline-tracking-body");
  if (!tbody) return;

  const channels = ["drone", "military", "family"];
  const phases = getAllPhaseGrades();
  const names = {
    "phase-01-trends": "Trends & Research",
    "phase-02-automation": "Automation & Drafts",
    "phase-03-avatar": "Avatar Narrative",
    "phase-04-strategy": "Strategy Session",
    "phase-05-ai-review": "AI Review & Testing",
    "phase-06-mission-control": "Mission Control Submit",
    "phase-07-analytics": "Analytics & Scoring",
    "phase-08-week-one": "Week One Evaluation",
    "phase-09-tracking": "Pipeline Tracking",
  };

  tbody.innerHTML = channels
    .map((ch) => {
      const avg =
        phases.reduce((s, p) => s + p.pct, 0) / (phases.length || 1);
      const grade = avg >= 70 ? "PASS" : avg > 0 ? "FAIL" : "PENDING";
      const cls = grade === "PASS" ? "grade-pass" : grade === "FAIL" ? "grade-fail" : "grade-pending";
      return `
      <tr>
        <td><strong>${capitalize(ch)}</strong></td>
        <td>${phases.filter((p) => p.grade === "PASS").length} / 9</td>
        <td>${Math.round(avg)}%</td>
        <td><span class="grade-badge ${cls}">${grade}</span></td>
        <td><a href="channels/${ch === "military" ? "military-bases" : ch === "drone" ? "drone-technology" : "family"}.html" class="btn">View</a></td>
      </tr>`;
    })
    .join("");

  const phaseHrefs = {
    "phase-01-trends": "phases/01-trends.html",
    "phase-02-automation": "phases/02-automation.html",
    "phase-03-avatar": "phases/03-avatar.html",
    "phase-04-strategy": "phases/04-strategy.html",
    "phase-05-ai-review": "phases/05-ai-review.html",
    "phase-06-mission-control": "phases/06-mission-control.html",
    "phase-07-analytics": "phases/07-analytics.html",
    "phase-08-week-one": "phases/08-week-one.html",
    "phase-09-tracking": "phases/09-tracking.html",
  };

  const phaseBody = document.getElementById("phase-status-body");
  if (phaseBody) {
    phaseBody.innerHTML = phases
      .map((p) => {
        const cls =
          p.grade === "PASS" ? "grade-pass" : p.grade === "FAIL" ? "grade-fail" : "grade-pending";
        return `
      <tr>
        <td>${names[p.id] || p.id}</td>
        <td>${p.pct}%</td>
        <td><span class="grade-badge ${cls}">${p.grade || "PENDING"}</span></td>
        <td class="text-muted text-small">${p.updatedAt ? formatTime(p.updatedAt) : "—"}</td>
        <td><a href="${phaseHrefs[p.id] || "#"}" class="btn">Open</a></td>
      </tr>`;
      })
      .join("");
  }

  const passCount = phases.filter((p) => p.grade === "PASS").length;
  const pendingCount = phases.filter((p) => p.grade === "PENDING" || !p.grade).length;

  setMetric("metric-phases-pass", passCount);
  setMetric("metric-phases-pending", pendingCount);
  setMetric("metric-channels", "3");
}

function setMetric(id, val) {
  const el = document.getElementById(id);
  if (el) el.textContent = val;
}

function capitalize(s) {
  return s.charAt(0).toUpperCase() + s.slice(1).replace("-", " ");
}

function setActiveNav() {
  const path = window.location.pathname;
  document.querySelectorAll("nav.main-nav a").forEach((a) => {
    const href = a.getAttribute("href");
    if (href && path.endsWith(href.replace(/^\//, ""))) {
      a.classList.add("active");
    }
  });
}

document.addEventListener("DOMContentLoaded", () => {
  setActiveNav();
  if (document.getElementById("pipeline-tracking-body")) {
    renderDashboard();
  }
});
