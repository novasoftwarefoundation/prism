# 0011: The image picker: a preview and the app's own button

Status: proposed, 2026-11-02

## Context

A consumer app lets people pick an image in two places: a profile photo and an image for a page (Flux 10465600000). Both show a preview and a button beside it. The preview is round for a photo (120×120) and rectangular for an image (120×90), on a light grey (`grey4`) with a 2px `grey4` frame, and shows the picked image or the app's placeholder. The button is primary while there is no image, secondary once there is one, and opens a hidden file input. A label above it is the app's (Prism's field label).

Prism has the button and the typography, but not the preview's look.

## Decision

1. **A component, `image_picker`.** It is one concept: a preview of an image and a way to choose one, as SwiftUI's `PhotosPicker` and Android's photo picker are one. The name says what is picked: an image, any picture, not only a camera photo; Flutter's and React Native's packages call it the same (`image_picker`). Material 3, Fluent 2, Carbon, Polaris, Atlassian and Spectrum have no such component; Polaris's `DropZone` and Carbon's file uploader are about files of any kind, without a preview.

2. **Two parts.**
   - `preview`: a box the app fills with its image (`<img>` on the web, any view on iOS), or with its placeholder. The image covers the box and is clipped to its shape (`object-fit: cover`; `.clipShape` on iOS).
   - `button`: the button component itself (`part :button, component: :button`). The app renders it, with the variant it picks (primary while empty, secondary with an image), its label, and its action. Prism doesn't wrap it: on the web the app's button is a `<label>` for its file input, or a `<button>`, and on iOS a `Button` with Prism's style. The format calls such a part one the app renders itself; the components put the app's markup in its place (a `<:button>` slot in Phoenix, a `button` prop in React, a `button:` view in Swift).

3. **The shape is an axis**, `shape`, with `rectangular` as its default and `round`. `rectangular` is the component's own look, without a class; `round` changes the preview's height and radius (`--round`).

4. **The file input is the app's**, as is what happens on a pick (uploading, the placeholder, the label). Prism is look only.

5. **Prism's values:**
   - the preview is 120×90 on `grey4` with a 2px `grey4` border;
   - round, it is 120×120 with the full radius;
   - the button is 24px from the preview, and the two are centered on one row.

   The consumer app makes both larger from its small breakpoint (200×150, 150×150). The format has no breakpoints, so an app that wants that sets the preview's size with its own classes.

6. **The format gets `width`**, a length, beside `size` and `height`, for a box that isn't square. The web writes `width`, iOS the frame's width, the overview the box's width.

## Alternatives

| Option | Why not |
|---|---|
| No component, only a preview look (`image_preview`) | The row, the spacing and the shapes would be repeated in each app beside its button. |
| The button rendered by the image picker, with a variant chosen by a state (`empty`) | The button's element and action are the app's (a label for a file input, a `PhotosPicker` on iOS); a button rendered by Prism would need all of the button's attributes on the picker. |
| Separate components `photo_picker` and `image_picker` | One look with two shapes; an axis keeps it one component. |
| `avatar` for the round one | An avatar shows a person; this picks an image, also when it is a profile photo. |
| The preview's size as `size` and an aspect ratio | A width and a height say the box as it is, also on iOS and in the overview. |

## Consequences

- An app shows an image picker with Prism's look on the web and on iOS, and keeps its own file input and button action.
- `components.css` gets an "Image pickers" section; the golden diff (`design/test/golden/0.1.7.diff`) holds it.
- The targets know thirteen components. The React package ships `ImagePicker`.
- The format has `width`, and parts that the app renders itself.
