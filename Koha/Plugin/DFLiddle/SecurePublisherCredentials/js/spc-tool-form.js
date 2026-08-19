(function () {
  "use strict";

  var form = document.querySelector("form");
  if (!form) return;
  form.addEventListener("submit", function () {
    var typeEl = form.querySelector("input[name=access_scope_type]:checked");
    if (!typeEl) return;
    var type = typeEl.value;
    var hidden = form.querySelector("input[name=access_scope_code]");
    if (!hidden) {
      hidden = document.createElement("input");
      hidden.type = "hidden";
      hidden.name = "access_scope_code";
      form.appendChild(hidden);
    }
    if (type === "library") {
      hidden.value = form.querySelector("[name=access_scope_code_library]").value;
    } else if (type === "library_group") {
      hidden.value = form.querySelector("[name=access_scope_code_group]").value;
    } else {
      hidden.value = "";
    }
  });
})();
