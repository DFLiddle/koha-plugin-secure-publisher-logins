(function () {
  "use strict";

  var API_BASE = "/api/v1/contrib/secure_publisher_credentials";

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

  function ensureModal() {
    var el = document.getElementById("spc-modal");
    if (el) return el;
    el = document.createElement("div");
    el.id = "spc-modal";
    el.className = "spc-modal hidden";
    el.innerHTML =
      '<div class="spc-modal-backdrop"></div>' +
      '<div class="spc-modal-dialog" role="dialog" aria-labelledby="spc-modal-title">' +
      '<h2 id="spc-modal-title"></h2>' +
      '<p class="spc-url"></p>' +
      '<p class="spc-patron-note"></p>' +
      '<p class="spc-staff-note"><strong>Staff note:</strong> <span></span></p>' +
      '<div class="spc-field"><label>Username</label> <code class="spc-username"></code> ' +
      '<button type="button" class="spc-copy-user">Copy</button></div>' +
      '<div class="spc-field"><label>Password</label> <code class="spc-password"></code> ' +
      '<button type="button" class="spc-copy-pass">Copy</button></div>' +
      '<button type="button" class="spc-close">Close</button></div>';
    document.body.appendChild(el);
    el.querySelector(".spc-modal-backdrop").addEventListener("click", function () {
      el.classList.add("hidden");
    });
    el.querySelector(".spc-close").addEventListener("click", function () {
      el.classList.add("hidden");
    });
    return el;
  }

  function showModal(data) {
    var el = ensureModal();
    el.querySelector("#spc-modal-title").textContent = data.publisher_name || "Login info";
    var urlEl = el.querySelector(".spc-url");
    if (data.url) {
      if (data.url_valid_link) {
        urlEl.innerHTML = '<a href="' + data.url + '" target="_blank" rel="noopener">' + data.url + "</a>";
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
    el.querySelector(".spc-copy-user").onclick = function () {
      copyText(data.username || "");
    };
    el.querySelector(".spc-copy-pass").onclick = function () {
      copyText(data.password || "").then(function () {
        el.classList.add("hidden");
      });
    };
    el.classList.remove("hidden");
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

  function findStaffToolbar() {
    var selectors = [
      "#toolbar",
      ".toolbar",
      "#cat-toolbar",
      ".cat-toolbar",
      "div.toolbar",
    ];
    var i;
    for (i = 0; i < selectors.length; i++) {
      var hit = document.querySelector(selectors[i]);
      if (hit) return hit;
    }
    return null;
  }

  function injectStaffLink(biblionumber) {
    fetchJson(API_BASE + "/biblios/" + biblionumber + "/availability?interface=staff")
      .then(function (res) {
        if (!res.show) return;
        if (document.querySelector(".spc-view-login")) return;
        var toolbar = findStaffToolbar();
        if (!toolbar) return;
        var span = document.createElement("span");
        span.className = "spc-toolbar";
        var a = document.createElement("a");
        a.className = "btn btn-default spc-view-login";
        a.href = "#";
        a.setAttribute("data-biblionumber", biblionumber);
        a.innerHTML = '<i class="fa fa-lock" aria-hidden="true"></i> ' + (res.label || "View login info");
        span.appendChild(a);
        toolbar.appendChild(span);
        bindViewButtons();
      })
      .catch(function () {
        /* API unavailable or no match */
      });
  }

  function initStaff() {
    bindViewButtons();
    if (!/\/catalogue\/detail\.pl/.test(window.location.pathname)) return;
    var bib = getBiblionumber();
    if (bib && !document.querySelector(".spc-view-login")) {
      injectStaffLink(bib);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initStaff);
  } else {
    initStaff();
  }
})();
