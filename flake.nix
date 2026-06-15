{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        # svgo config applied to the build-sandbox SVG copies (never your repo files).
        #
        # 1. prefixIds: give every SVG a unique, filename-derived id prefix (id="a" ->
        #    id="values-types+modes_svg__a", with every #ref / xlink:href rewritten to
        #    suit) so that inlining several Lucid SVGs into one document does not
        #    collide. Stroke/fill colours and geometry are left untouched.
        #
        # 2. tag-mode-labels (custom): Lucid colours a text label by putting the fill on
        #    its glyph <path> defs (inside <defs>), which are never painted directly --
        #    the visible word is a body <use> that carries no colour, so a selector like
        #    [fill="#008a0e"] cannot reach it. This traces colour -> glyph def -> word
        #    <g> -> rendered <use> and copies the colour onto that rendered <use>, so the
        #    same stroke/fill selectors that animate the circles also catch their labels.
        #    TRACK lists the mode colours (the green/blue circle colours).
        svgoConfig = pkgs.writeText "svgo.config.js" ''
          const TRACK = ['#008a0e', '#1071e5'];

          const tagModeLabels = {
            name: 'tag-mode-labels',
            fn: (root) => {
              const all = [];
              const walk = (n) => { if (n.type === 'element') all.push(n); (n.children || []).forEach(walk); };
              walk(root);
              const href = (n) => {
                const a = n.attributes || {};
                const h = a['xlink:href'] || a.href || "";
                return h.startsWith('#') ? h.slice(1) : "";
              };
              for (const colour of TRACK) {
                const glyphIds = new Set(all
                  .filter((n) => n.name === 'path' && (n.attributes || {}).fill === colour && (n.attributes || {}).id)
                  .map((n) => n.attributes.id));
                if (!glyphIds.size) continue;
                const groupIds = new Set();
                for (const g of all.filter((n) => n.name === 'g' && (n.attributes || {}).id)) {
                  const uses = [];
                  const w = (n) => { if (n.name === 'use') uses.push(n); (n.children || []).forEach(w); };
                  w(g);
                  if (uses.some((u) => glyphIds.has(href(u)))) groupIds.add(g.attributes.id);
                }
                if (!groupIds.size) continue;
                for (const u of all.filter((n) => n.name === 'use')) {
                  if (groupIds.has(href(u))) {
                    u.attributes = u.attributes || {};
                    u.attributes.fill = colour;
                  }
                }
              }
              return {};
            },
          };

          module.exports = {
            plugins: [
              {
                name: 'prefixIds',
                params: { delim: '__', prefixIds: true, prefixClassNames: false },
              },
              tagModeLabels,
            ],
          };
        '';

        slides = pkgs.stdenvNoCC.mkDerivation {
          pname = "oxcaml-slides";
          version = "0.1.0";
          src = pkgs.lib.cleanSource ./slides;

          nativeBuildInputs = [
            pkgs.slipshow
            pkgs.svgo
          ];

          dontConfigure = true;

          buildPhase = ''
            runHook preBuild

            # We need to make the IDs within all SVGs unique, because Slipshow 0.9.X inlines all images into the output
            svgo -rf . --config ${svgoConfig}

            # Actually compile the slideshow
            slipshow compile --theme oxcaml.css index.md

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out
            cp index.html $out/
            # Carry along any non-inlined runtime assets (raster images, fonts, ...).
            [ -d assets ] && cp -r assets $out/

            runHook postInstall
          '';
        };
      in
      {
        packages.default = slides;

        devShell = pkgs.mkShell {
          inputsFrom = [ slides ];
          buildInputs = [
            pkgs.python313Packages.qrcode
          ];
        };
      }
    );
}
