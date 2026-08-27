(function () {
  "use strict";

  var API_BASE =
    (window.SPC && window.SPC.API_BASE) ||
    "/api/v1/contrib/secure_publisher_credentials";
  var VIEW_LABEL =
    (window.SPC && window.SPC.VIEW_LABEL) || "View login info";
  var LOGIN_TO_CHECK_LABEL =
    (window.SPC && window.SPC.LOGIN_TO_CHECK_LABEL) || "Log in to check access";
  var LIBRARY_NOT_SUBSCRIBED_LABEL =
    (window.SPC && window.SPC.LIBRARY_NOT_SUBSCRIBED_LABEL) ||
    "Library not subscribed";
  var SCOPE_DENIED_MESSAGE =
    (window.SPC && window.SPC.SCOPE_DENIED_MESSAGE) ||
    "Your library is not subscribed to this online resource. Click the link below to suggest it for purchase.";
  var SUGGEST_FOR_PURCHASE_LABEL =
    (window.SPC && window.SPC.SUGGEST_FOR_PURCHASE_LABEL) ||
    "Suggest for purchase";
  var LOGIN_INFO_NOT_AVAILABLE_LABEL =
    (window.SPC && window.SPC.LOGIN_INFO_NOT_AVAILABLE_LABEL) ||
    "Login info not available";
  var ACCOUNT_BLOCKED_MESSAGE =
    (window.SPC && window.SPC.ACCOUNT_BLOCKED_MESSAGE) ||
    "Your account requires attention before the login info can be shown. Please write to %s for help.";

  var POST_LOGIN_KEY = "spc_post_login_bib";

  function closeInfoModal() {
    var el = document.getElementById("spc-info-modal");
    if (el) {
      el.classList.remove("show");
      el.style.display = "none";
      el.setAttribute("aria-hidden", "true");
    }
    var backdrop = document.getElementById("spc-modal-backdrop");
    if (backdrop) backdrop.remove();
    document.body.classList.remove("modal-open");
  }

  function closeAllModals() {
    closeModal();
    closeInfoModal();
  }

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
    if (!document.getElementById("spc-info-modal") || !document.getElementById("spc-info-modal").classList.contains("show")) {
      var backdrop = document.getElementById("spc-modal-backdrop");
      if (backdrop) backdrop.remove();
      document.body.classList.remove("modal-open");
    }
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
      if (e.key === "Escape") closeAllModals();
    });
    return el;
  }

  function ensureInfoModal() {
    var el = document.getElementById("spc-info-modal");
    if (el) return el;
    el = document.createElement("div");
    el.id = "spc-info-modal";
    el.className = "modal";
    el.setAttribute("tabindex", "-1");
    el.setAttribute("role", "dialog");
    el.setAttribute("aria-labelledby", "spc-info-modal-title");
    el.setAttribute("aria-hidden", "true");
    el.innerHTML =
      '<div class="modal-dialog">' +
      '<div class="modal-content">' +
      '<div class="modal-header">' +
      '<h1 class="modal-title" id="spc-info-modal-title"></h1>' +
      '<button type="button" class="btn-close spc-info-close" aria-label="Close"></button>' +
      "</div>" +
      '<div class="modal-body">' +
      '<p class="spc-info-message"></p>' +
      '<p class="spc-info-suggestion"></p>' +
      "</div>" +
      '<div class="modal-footer">' +
      '<button type="button" class="btn btn-default spc-info-close spc-info-close-text">Close</button>' +
      "</div></div></div>";
    document.body.appendChild(el);
    el.querySelectorAll(".spc-info-close").forEach(function (btn) {
      btn.addEventListener("click", closeInfoModal);
    });
    el.addEventListener("click", function (e) {
      if (e.target === el) closeInfoModal();
    });
    return el;
  }

  function showInfoModal(title, message, actionHtml) {
    closeModal();
    var el = ensureInfoModal();
    el.querySelector("#spc-info-modal-title").textContent = title;
    el.querySelector(".spc-info-message").textContent = message;
    var actionEl = el.querySelector(".spc-info-suggestion");
    if (actionHtml) {
      actionEl.innerHTML = actionHtml;
    } else {
      actionEl.textContent = "";
    }
    ensureBackdrop();
    document.body.classList.add("modal-open");
    el.classList.add("show");
    el.style.display = "block";
    el.setAttribute("aria-hidden", "false");
  }

  function showScopeDeniedModal(res) {
    var title = res.label || LIBRARY_NOT_SUBSCRIBED_LABEL;
    var message = res.modal_message || SCOPE_DENIED_MESSAGE;
    var linkLabel = res.suggestion_link_label || SUGGEST_FOR_PURCHASE_LABEL;
    var suggestionUrl = res.suggestion_url || "";
    var actionHtml = "";
    if (suggestionUrl) {
      actionHtml =
        '<a href="' +
        suggestionUrl +
        '" class="btn btn-default">' +
        linkLabel +
        "</a>";
    }
    showInfoModal(title, message, actionHtml);
  }

  function formatAccountBlockedMessage(res) {
    if (res.modal_message) return res.modal_message;
    var email = res.help_email || "";
    var placeholder = email || "your library";
    return ACCOUNT_BLOCKED_MESSAGE.replace("%s", placeholder);
  }

  function showAccountBlockedModal(res) {
    var title = res.label || LOGIN_INFO_NOT_AVAILABLE_LABEL;
    var message = formatAccountBlockedMessage(res);
    var email = res.help_email || "";
    var actionHtml = "";
    if (email) {
      actionHtml =
        '<a href="mailto:' + email + '" class="btn btn-default">' + email + "</a>";
    }
    showInfoModal(title, message, actionHtml);
  }

  function applyUi(el, ui) {
    if (!ui) return;
    var user = el.querySelector(".spc-label-user");
    var pass = el.querySelector(".spc-label-pass");
    var copyUser = el.querySelector(".spc-copy-user");
    var copyPass = el.querySelector(".spc-copy-pass");
    var closeText = el.querySelector(".spc-close-text");
    var closeAria = el.querySelector(".btn-close");
    if (user && ui.username) user.textContent = ui.username;
    if (pass && ui.password) pass.textContent = ui.password;
    if (copyUser && ui.copy) copyUser.textContent = ui.copy;
    if (copyPass && ui.copy) copyPass.textContent = ui.copy;
    if (closeText && ui.close) closeText.textContent = ui.close;
    if (closeAria && ui.close) closeAria.setAttribute("aria-label", ui.close);
  }

  function showModal(data) {
    var el = ensureModal();
    el.querySelector("#spc-modal-title").textContent =
      data.publisher_name ||
      (data.ui && data.ui.login_info) ||
      "Login info";
    var urlEl = el.querySelector(".spc-url");
    if (data.url) {
      if (data.url_valid_link) {
        urlEl.innerHTML =
          '<a href="' +
          data.url +
          '" target="_blank" rel="noopener">' +
          data.url +
          "</a>";
      } else {
        urlEl.textContent = data.url;
      }
    } else {
      urlEl.textContent = "";
    }
    el.querySelector(".spc-patron-note").textContent = data.patron_note || "";
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

  function openView(biblionumber, iface) {
    return fetchJson(
      API_BASE + "/biblios/" + biblionumber + "/view?interface=" + iface
    ).then(showModal);
  }

  function returnUrlForRecord() {
    return window.location.pathname + window.location.search;
  }

  function startLoginFlow(biblionumber) {
    try {
      sessionStorage.setItem(POST_LOGIN_KEY, biblionumber);
    } catch (e) {
      /* private mode */
    }

    var returnUrl = returnUrlForRecord();
    var modalAuth = document.getElementById("modalAuth");
    var loginModal = document.getElementById("loginModal");

    if (modalAuth && loginModal && typeof jQuery !== "undefined") {
      var old = modalAuth.querySelector('input[name="return"]');
      if (old) old.remove();
      var input = document.createElement("input");
      input.type = "hidden";
      input.name = "return";
      input.value = returnUrl;
      modalAuth.appendChild(input);
      jQuery("#loginModal").modal("show");
      return;
    }

    window.location.href =
      "/cgi-bin/koha/opac-auth.pl?return=" + encodeURIComponent(returnUrl);
  }

  function linkShouldShow(res) {
    if (!res) return false;
    if (
      res.state === "login_required" ||
      res.state === "view_allowed" ||
      res.state === "scope_denied" ||
      res.state === "account_blocked"
    ) {
      return true;
    }
    return res.show === 1;
  }

  function labelForState(res) {
    if (res.label) return res.label;
    if (res.state === "login_required") return LOGIN_TO_CHECK_LABEL;
    if (res.state === "scope_denied") return LIBRARY_NOT_SUBSCRIBED_LABEL;
    if (res.state === "account_blocked") return LOGIN_INFO_NOT_AVAILABLE_LABEL;
    return VIEW_LABEL;
  }

  function bindLinkClick(a, biblionumber, state, res) {
    a.onclick = function (e) {
      e.preventDefault();
      if (state === "login_required") {
        startLoginFlow(biblionumber);
      } else if (state === "scope_denied") {
        showScopeDeniedModal(res);
      } else if (state === "account_blocked") {
        showAccountBlockedModal(res);
      } else {
        openView(biblionumber, "opac");
      }
    };
  }

  function leadingIconClass(state) {
    if (state === "view_allowed") return "fa-solid fa-unlock";
    return "fa-solid fa-lock";
  }

  function trailingIconClass(state) {
    if (state === "scope_denied" || state === "account_blocked") {
      return "fa-regular fa-circle-question";
    }
    return "";
  }

  function linkIconHtml(state, label) {
    var html =
      '<i class="' + leadingIconClass(state) + '" aria-hidden="true"></i> ' + label;
    var trailing = trailingIconClass(state);
    if (trailing) {
      html +=
        ' <i class="' + trailing + ' spc-icon-trailing" aria-hidden="true"></i>';
    }
    return html;
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

  function renderOpacLink(biblionumber, res) {
    if (!linkShouldShow(res)) return;

    var ul = findOpacActionList();
    if (!ul) {
      console.warn("SPC: OPAC action list not found");
      return;
    }

    var state = res.state || (res.show ? "view_allowed" : "hidden");
    var label = labelForState(res);
    var a = ul.querySelector(".spc-opac-login-link");
    if (!a) {
      var li = document.createElement("li");
      a = document.createElement("a");
      a.className = "btn btn-link btn-lg spc-opac-login-link";
      a.href = "#";
      li.appendChild(a);
      ul.insertBefore(li, ul.firstChild);
    }

    a.innerHTML = linkIconHtml(state, label);
    a.setAttribute("data-spc-state", state);
    bindLinkClick(a, biblionumber, state, res);
  }

  function fetchAvailability(biblionumber) {
    return fetchJson(
      API_BASE + "/biblios/" + biblionumber + "/availability?interface=opac"
    );
  }

  function handlePostLoginFlow(biblionumber) {
    var stored;
    try {
      stored = sessionStorage.getItem(POST_LOGIN_KEY);
    } catch (e) {
      return Promise.resolve();
    }
    if (!stored || stored !== biblionumber) {
      return Promise.resolve();
    }
    try {
      sessionStorage.removeItem(POST_LOGIN_KEY);
    } catch (e) {
      /* ignore */
    }

    return fetchAvailability(biblionumber).then(function (res) {
      if (res.state === "view_allowed" || res.show) {
        return openView(biblionumber, "opac");
      }
      if (res.state === "scope_denied") {
        showScopeDeniedModal(res);
      }
      if (res.state === "account_blocked") {
        showAccountBlockedModal(res);
      }
    });
  }

  function injectOpacLink(biblionumber) {
    return fetchAvailability(biblionumber)
      .then(function (res) {
        renderOpacLink(biblionumber, res);
      })
      .catch(function (err) {
        console.warn("SPC: OPAC availability check failed", err);
      });
  }

  function initOpac() {
    if (!/\/opac-detail\.pl/.test(window.location.pathname)) return;
    var bib = getBiblionumber();
    if (!bib) return;

    handlePostLoginFlow(bib)
      .catch(function (err) {
        console.warn("SPC: post-login flow failed", err);
      })
      .then(function () {
        return injectOpacLink(bib);
      });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initOpac);
  } else {
    initOpac();
  }
})();
