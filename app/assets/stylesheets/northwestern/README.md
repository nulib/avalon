# Northwestern branding for AVR

Extends Avalon, Blacklight, and Bootstrap styling to apply Northwestern
branding across the application.

## How it's wired

One line at the bottom of `app/assets/stylesheets/application.sass.scss`:

```scss
@import 'northwestern';
```

The import is **last on purpose**. Everything here is an override layer that
wins on source order, so the AVR delta in upstream's own stylesheets stays at
that single line and `application.sass.scss` keeps merging cleanly across
Avalon releases. See `docs/AVR_UPGRADE.md`.

The corollary: the variable assignments in `branding/` are *inert with respect
to upstream*. By the time this package is imported, Bootstrap and Avalon have
already been compiled with their own values, so reassigning `$primary` here
changes nothing they emitted — it only supplies values to the files under
`components/`. Where a Bootstrap-derived rule has to change, it is overridden
explicitly, or through the `--bs-*` custom properties set in
`branding/_colors.scss`.

## Assets

Images are referenced with paths relative to the compiled stylesheet, which
Sprockets serves from `/assets/`:

```scss
background: url('images/logos/northwestern.svg');   // app/assets/images/images/logos/...
```

The doubled `images/images` is not a typo — the first segment is the Sprockets
mount point, the second is a real directory. Only the assets actually
referenced from here (and from the two `modules/*__northwestern` partials) are
in the repo; the rest of Northwestern's 2019 asset drop is still on
`nu/deploy/production` if a future design needs it.

CSS is built by dart-sass through `yarn build:css`, not by Sprockets, so
`image-url()` and friends are unavailable — plain `url()` only.

## Markup coupling

These rules are written against Bootstrap 5, Blacklight 8, and Avalon 8.2
markup. The selectors most likely to rot on the next upgrade:

- `div.mb-3:has(> #link-object-manifest)` — hides the IIIF manifest share
  field. Bootstrap 4's `.form-group` wrapper became `.mb-3` in Avalon 8; if
  that field moves again this silently stops hiding it.
- `.facets-header` / `h2.facets-heading` — Blacklight 8's facet sidebar
  heading, formerly `.top-panel-heading`.
- `.btn-group-toggle` / `.sort-btn` — dropped by Bootstrap 5 but still emitted
  by `app/javascript/components/collections/list/CollectionListStickyUtils.js`.
- `.navbar-header` — Bootstrap 3/4 vintage, still in
  `app/views/modules/_global_navigation.html.erb`.
