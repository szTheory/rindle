(function () {
  var themes = ["light", "dark", "auto"];
  var allowed = Object.create(null);

  themes.forEach(function (theme) {
    allowed[theme] = true;
  });

  function normalize(value) {
    return allowed[value] ? value : "auto";
  }

  function applyTheme(root, theme) {
    var nextTheme = normalize(theme);
    root.setAttribute("data-theme", nextTheme);

    root.querySelectorAll("[data-rindle-admin-theme]").forEach(function (control) {
      var controlTheme = normalize(control.getAttribute("data-rindle-admin-theme"));
      control.setAttribute("aria-pressed", controlTheme === nextTheme ? "true" : "false");
    });
  }

  function bindRoot(root) {
    var initialTheme = normalize(root.getAttribute("data-theme"));
    applyTheme(root, initialTheme);

    root.addEventListener("click", function (event) {
      var control = event.target.closest("[data-rindle-admin-theme]");

      if (!control || !root.contains(control)) {
        return;
      }

      applyTheme(root, control.getAttribute("data-rindle-admin-theme"));
    });
  }

  document.querySelectorAll("[data-rindle-admin-root]").forEach(bindRoot);
})();
