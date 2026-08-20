(function () {
  "use strict";

  var API_BASE = (window.SPC && window.SPC.API_BASE) || "/api/v1/contrib/secure_publisher_credentials";
  var VIEW_LABEL = (window.SPC && window.SPC.VIEW_LABEL) || "View login info";
  var MANAGE_LABEL = (window.SPC && window.SPC.MANAGE_LABEL) || "Manage login info";

  function getBiblionumber() {
    var m = window.location.search.match(/[?&]biblionumber=(\d+)/);
    return m ? m[1] : null;
  }

  function fetchJson(url) {
    return fetch(url, {
      credentials: "same-origin",
      headers: { Accept: "application/json" },
    }).then(function (r) {
      if (!r.ok) throw new Error("HTTP " + r.status);
      return r.json();
    });
  }

  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
    var ta = document.createElement("textarea");
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand("copy");
    document.body.removeChild(ta);
    return Promise.resolve();
  }

  function closeModal() {
    var el = document.getElementById("spc-modal");
    if (el) {
      el.classList.remove("show");
      el.style.display = "none";
      el.setAttribute("aria-hidden", "true");
    }
    var backdrop = document.getElementById("spc-modal-backdrop");
    if (backdrop) backdrop.remove();
    document.body.classList.remove("modal-open");
  }

  function ensureBackdrop() {
    var backdrop = document.getElementById("spc-modal-backdrop");
    if (backdrop) return;
    backdrop = document.createElement("div");
    backdrop.id = "spc-modal-backdrop";
    backdrop.className = "modal-backdrop show";
    document.body.appendChild(backdrop);
  }

  function ensureModal() {
    var el = document.getElementById("spc-modal");
    if (el) return el;
    el = document.createElement("div");
    el.id = "spc-modal";
    el.className = "modal";
    el.setAttribute("tabindex", "-1");
    el.setAttribute("role", "dialog");
    el.setAttribute("aria-labelledby", "spc-modal-title");
    el.setAttribute("aria-hidden", "true");
    el.innerHTML =
      '<div class="modal-dialog modal-lg">' +
      '<div class="modal-content">' +
      '<div class="modal-header">' +
      '<h1 class="modal-title" id="spc-modal-title"></h1>' +
      '<button type="button" class="btn-close spc-close" aria-label="Close"></button>' +
      "</div>" +
      '<div class="modal-body">' +
      '<p class="spc-url"></p>' +
      '<p class="spc-patron-note"></p>' +
      '<p class="spc-staff-note"><strong class="spc-staff-note-label">Staff note:</strong> <span></span></p>' +
      '<div class="spc-field"><label class="spc-label-user">Username:</label> <code class="spc-username"></code> ' +
      '<button type="button" class="btn btn-default spc-copy-user">Copy</button></div>' +
      '<div class="spc-field"><label class="spc-label-pass">Password:</label> <code class="spc-password"></code> ' +
      '<button type="button" class="btn btn-default spc-copy-pass">Copy</button></div>' +
      "</div>" +
      '<div class="modal-footer">' +
      '<button type="button" class="btn btn-default spc-close spc-close-text">Close</button>' +
      "</div></div></div>";
    document.body.appendChild(el);
    el.querySelectorAll(".spc-close").forEach(function (btn) {
      btn.addEventListener("click", closeModal);
    });
    el.addEventListener("click", function (e) {
      if (e.target === el) closeModal();
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") closeModal();
    });
    return el;
  }

  function applyUi(el, ui) {
    if (!ui) return;
    var user = el.querySelector(".spc-label-user");
    var pass = el.querySelector(".spc-label-pass");
    var copyUser = el.querySelector(".spc-copy-user");
    var copyPass = el.querySelector(".spc-copy-pass");
    var closeText = el.querySelector(".spc-close-text");
    var staffLabel = el.querySelector(".spc-staff-note-label");
    var closeAria = el.querySelector(".btn-close");
    if (user && ui.username) user.textContent = ui.username;
    if (pass && ui.password) pass.textContent = ui.password;
    if (copyUser && ui.copy) copyUser.textContent = ui.copy;
    if (copyPass && ui.copy) copyPass.textContent = ui.copy;
    if (closeText && ui.close) closeText.textContent = ui.close;
    if (staffLabel && ui.staff_note) staffLabel.textContent = ui.staff_note;
    if (closeAria && ui.close) closeAria.setAttribute("aria-label", ui.close);
  }

  function showModal(data) {
    var el = ensureModal();
    el.querySelector("#spc-modal-title").textContent =
      data.publisher_name || (data.ui && data.ui.login_info) || "Login info";
    var urlEl = el.querySelector(".spc-url");
    if (data.url) {
      if (data.url_valid_link) {
        urlEl.innerHTML =
          '<a href="' + data.url + '" target="_blank" rel="noopener">' + data.url + "</a>";
      } else {
        urlEl.textContent = data.url;
      }
    } else {
      urlEl.textContent = "";
    }
    el.querySelector(".spc-patron-note").textContent = data.patron_note || "";
    var staffNote = el.querySelector(".spc-staff-note span");
    if (data.staff_note) {
      staffNote.textContent = data.staff_note;
      el.querySelector(".spc-staff-note").style.display = "";
    } else {
      el.querySelector(".spc-staff-note").style.display = "none";
    }
    el.querySelector(".spc-username").textContent = data.username || "";
    el.querySelector(".spc-password").textContent = data.password || "";
    applyUi(el, data.ui);
    el.querySelector(".spc-copy-user").onclick = function () {
      copyText(data.username || "");
    };
    el.querySelector(".spc-copy-pass").onclick = function () {
      copyText(data.password || "").then(closeModal);
    };
    ensureBackdrop();
    document.body.classList.add("modal-open");
    el.classList.add("show");
    el.style.display = "block";
    el.setAttribute("aria-hidden", "false");
  }

  function openView(biblionumber) {
    fetchJson(API_BASE + "/biblios/" + biblionumber + "/view?interface=staff").then(showModal);
  }

  function bindViewButtons() {
    document.querySelectorAll(".spc-view-login").forEach(function (btn) {
      if (btn.getAttribute("data-spc-bound")) return;
      btn.setAttribute("data-spc-bound", "1");
      btn.addEventListener("click", function (e) {
        e.preventDefault();
        var bn = btn.getAttribute("data-biblionumber");
        if (bn) openView(bn);
      });
    });
  }

  function catalogueDetailRoot() {
    var selectors = [
      "#maincontentcontainer",
      "#maincontent",
      "#bibliodetails",
      ".maincontent",
    ];
    var i;
    for (i = 0; i < selectors.length; i++) {
      var hit = document.querySelector(selectors[i]);
      if (hit) return hit;
    }
    return null;
  }

  function findStaffToolbar() {
    var root = catalogueDetailRoot();
    if (!root) return null;

    var scoped = [
      "#toolbar",
      ".btn-toolbar",
      "#cat-toolbar",
      ".cat-toolbar",
    ];
    var i;
    for (i = 0; i < scoped.length; i++) {
      var hit = root.querySelector(scoped[i]);
      if (hit) return hit;
    }

    // Toolbar is a row of btn-groups (New / Edit / Save / Print …).
    var btnGroups = root.querySelectorAll(".btn-group");
    if (btnGroups.length) {
      var parent = btnGroups[0].parentElement;
      if (parent) return parent;
    }
    return null;
  }

  function ensureToolbarContainer(toolbar) {
    var existing = document.querySelector(".spc-toolbar");
    if (existing) return existing;

    var group = document.createElement("div");
    group.className = "btn-group spc-toolbar";
    group.setAttribute("role", "group");
    toolbar.appendChild(group);
    return group;
  }

  function injectStaffLink(biblionumber) {
    if (document.querySelector(".spc-view-login")) {
      bindViewButtons();
      return;
    }

    fetchJson(API_BASE + "/biblios/" + biblionumber + "/availability?interface=staff")
      .then(function (res) {
        if (!res.show) {
          console.warn("SPC: availability returned show=0 for bib " + biblionumber);
          return;
        }

        var toolbar = findStaffToolbar();
        if (!toolbar) {
          console.warn("SPC: catalogue toolbar container not found in detail content");
          return;
        }

        var container = ensureToolbarContainer(toolbar);

        if (!container.querySelector(".spc-view-login")) {
          var a = document.createElement("a");
          a.className = "btn btn-default spc-view-login";
          a.href = "#";
          a.setAttribute("data-biblionumber", biblionumber);
          a.innerHTML =
            '<i class="fa fa-lock" aria-hidden="true"></i> ' + (res.label || VIEW_LABEL);
          container.appendChild(a);
        }

        if (res.manage && res.manage_url && !container.querySelector(".spc-manage-login")) {
          var m = document.createElement("a");
          m.className = "btn btn-default spc-manage-login";
          m.href = res.manage_url;
          m.innerHTML =
            '<i class="fa fa-pencil" aria-hidden="true"></i> ' +
            (res.manage_label || MANAGE_LABEL);
          container.appendChild(m);
        }

        bindViewButtons();
      })
      .catch(function (err) {
        console.warn("SPC: availability check failed", err);
      });
  }

  function isStaffDetailPage() {
    var path = window.location.pathname || "";
    return /\/catalogue\/detail\.pl/.test(path);
  }

  function initStaff() {
    bindViewButtons();
    if (!isStaffDetailPage()) return;
    var bib = getBiblionumber();
    if (!bib) return;
    injectStaffLink(bib);
    window.setTimeout(function () {
      if (!document.querySelector(".spc-view-login")) {
        injectStaffLink(bib);
      }
    }, 400);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initStaff);
  } else {
    initStaff();
  }
})();
