/* The switcher. Two questions — which palette, and how light — kept in
   `localStorage` so the answer survives following a link to the next page.

   The buttons are built here rather than written into the footer because the
   families come from the app's scheme files: a palette added there appears
   here on the next `make palettes`, and a row of hardcoded buttons would not. */
(function () {
	var root = document.documentElement;
	var MODES = [["system", "System"], ["light", "Light"], ["dark", "Dark"]];

	function remember(key, value) {
		try { localStorage.setItem(key, value); } catch (error) { /* private window */ }
	}

	function apply(family, mode) {
		root.dataset.family = family;
		root.dataset.mode = mode;
		remember("palette", family);
		remember("lightness", mode);
		draw();
	}

	function fill(node, entries, attribute) {
		node.textContent = "";
		entries.forEach(function (entry) {
			var button = document.createElement("button");
			button.type = "button";
			button.textContent = entry[1];
			button.dataset[attribute] = entry[0];
			button.addEventListener("click", function () {
				attribute === "family"
					? apply(entry[0], root.dataset.mode || "system")
					: apply(root.dataset.family || "abydos", entry[0]);
			});
			node.appendChild(button);
		});
	}

	/* Which one is in force, said on the buttons themselves. `aria-pressed`
	   rather than a class, because that is the thing a screen reader reads and
	   the stylesheet can hang off it just as well. */
	function draw() {
		var family = root.dataset.family || "abydos";
		var mode = root.dataset.mode || "system";
		document.querySelectorAll(".picker button, button.try").forEach(function (button) {
			var wants = button.dataset.family, lightness = button.dataset.mode;
			button.setAttribute("aria-pressed", String(
				button.classList.contains("try")
					? wants === family && lightness === mode
					: (wants ? wants === family : lightness === mode)
			));
		});
	}

	var picker = document.getElementById("picker");
	if (picker) {
		fill(document.getElementById("picker-family"), PALETTES, "family");
		fill(document.getElementById("picker-mode"), MODES, "mode");
		picker.hidden = false;
	}

	/* The themes page's own buttons, one under each palette, which answer both
	   questions at once — this palette, at the lightness the section shows. */
	document.querySelectorAll("button.try").forEach(function (button) {
		button.hidden = false;
		button.addEventListener("click", function () {
			apply(button.dataset.family, button.dataset.mode);
		});
	});

	draw();
})();
