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
      '<div class="spc-field"><label>Username</label> <code class="spc-username"></code> ' +
      '<button type="button" class="spc-copy-user">Copy</button></div>' +
      '<div class="spc-field"><label>Password</label> <code class="spc-password"></code> ' +
      '<button type="button" class="spc-copy-pass">Copy</button></div>' +
      '<button type="button" class="spc-close">Close</button></div>';
    document.body.appendChild(el);

    el.querySelector(".spc-modal-backdrop").addEventListener("click", closeModal);
    el.querySelector(".spc-close").addEventListener("click", closeModal);
    return el;
  }

  function closeModal() {
    var el = document.getElementById("spc-modal");
    if (el) el.classList.add("hidden");
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
    el.querySelector(".spc-username").textContent = data.username || "";
    el.querySelector(".spc-password").textContent = data.password || "";

    el.querySelector(".spc-copy-user").onclick = function () {
      copyText(data.username || "");
    };
    el.querySelector(".spc-copy-pass").onclick = function () {
      copyText(data.password || "").then(closeModal);
    };

    el.classList.remove("hidden");
  }

  function openView(biblionumber, iface) {
    fetchJson(API_BASE + "/biblios/" + biblionumber + "/view?interface=" + iface).then(showModal);
  }

  function findOpacActionList() {
    var selectors = [
      "#ulactioncontainer ul#action",
      "#ulactioncontainer #actions ul",
      "#ulactioncontainer ul.nav",
      "#ulactioncontainer ul.actions",
      "ul#action",
    ];
    var i;
    for (i = 0; i < selectors.length; i++) {
      var hit = document.querySelector(selectors[i]);
      if (hit) return hit;
    }
    var container = document.getElementById("ulactioncontainer");
    if (container) {
      var uls = container.querySelectorAll("ul");
      for (i = 0; i < uls.length; i++) {
        if (uls[i].querySelector("a, button")) return uls[i];
      }
    }
    return null;
  }

  function injectOpacLink(biblionumber) {
    fetchJson(
      API_BASE + "/biblios/" + biblionumber + "/availability?interface=opac"
    )
      .then(function (res) {
        if (!res.show) return;
        var ul = findOpacActionList();
        if (!ul) return;
        if (ul.querySelector(".spc-opac-login-link")) return;
        var li = document.createElement("li");
        var a = document.createElement("a");
        a.className = "btn btn-link btn-lg spc-opac-login-link";
        a.href = "#";
        a.innerHTML = '<i class="fa fa-lock" aria-hidden="true"></i> ' + (res.label || "View login info");
        a.addEventListener("click", function (e) {
          e.preventDefault();
          openView(biblionumber, "opac");
        });
        li.appendChild(a);
        ul.insertBefore(li, ul.firstChild);
      })
      .catch(function () {
        /* API unavailable or no match — no link shown */
      });
  }

  function initOpac() {
    if (!/\/opac-detail\.pl/.test(window.location.pathname)) return;
    var bib = getBiblionumber();
    if (bib) injectOpacLink(bib);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initOpac);
  } else {
    initOpac();
  }
})();
