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

	/* Which folder the pictures come from: `<family>-<lightness>`, with
	   `system` resolved against the display, because a folder is a name and
	   `system` is a deferral rather than a palette. */
	function folder(family, mode) {
		var lightness = mode === "system"
			? (window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark")
			: mode;
		return family + "-" + lightness;
	}

	/* The screenshots follow the palette too, which is the claim the switcher is
	   making: a page in daylight showing eight windows at midnight would be a
	   demonstration of the opposite. Only the palette segment of the path moves —
	   the shot's own name is the rest of it — and a picture marked `data-fixed`
	   is one whose whole point is the palette it was taken in. */
	function pictures(family, mode) {
		var want = folder(family, mode);
		document.querySelectorAll("img[src*='/']").forEach(function (image) {
			if (image.hasAttribute("data-fixed")) return;
			var next = image.getAttribute("src")
				.replace(/images\/(thumbs\/)?[a-z0-9]+-(dark|light)\//, "images/$1" + want + "/");
			if (next !== image.getAttribute("src")) {
				image.setAttribute("src", next);
				var set = image.getAttribute("srcset");
				if (set) image.setAttribute("srcset", set.replace(/^\S+/, next));
			}
		});
	}

	function apply(family, mode) {
		root.dataset.family = family;
		root.dataset.mode = mode;
		remember("palette", family);
		remember("lightness", mode);
		pictures(family, mode);
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
					: apply(root.dataset.family || "blue", entry[0]);
			});
			node.appendChild(button);
		});
	}

	/* Which one is in force, said on the buttons themselves. `aria-pressed`
	   rather than a class, because that is the thing a screen reader reads and
	   the stylesheet can hang off it just as well. */
	function draw() {
		var family = root.dataset.family || "blue";
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

	pictures(root.dataset.family || "blue", root.dataset.mode || "system");
	draw();

	/* A display that changes under `System` moves the pictures with the colours.
	   The CSS does its half on its own; this is the other half. */
	window.matchMedia("(prefers-color-scheme: light)").addEventListener("change", function () {
		if ((root.dataset.mode || "system") === "system") {
			pictures(root.dataset.family || "blue", "system");
		}
	});
})();
