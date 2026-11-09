# Prism tokens for Webflow

"Prism tokens" is a Webflow Designer Extension. With one click it writes Prism's design tokens into a site's variables. Every Prism release ships it as `prism-tokens-webflow.zip` (on the release page, under Assets).

## Install it in the workspace (once)

You need to be a Workspace admin with two-factor authentication turned on, in a workspace whose plan allows building apps ([Register an app](https://developers.webflow.com/apps/data/docs/register-an-app)).

1. Go to Workspace settings, then **Apps & Integrations**, then **App Development**, and click **Create an App**.
   - Name it "Prism tokens" and choose the **Designer Extension** building block.
   - You can limit installation to one site.
2. In that section, find the app and click **Publish extension version**. Upload `prism-tokens-webflow.zip` from the Prism release ([Publishing your app](https://developers.webflow.com/apps/docs/publishing-your-app)).
3. Click the app's **…** button, then **Install**, and choose the site.

Apps you build for your own workspace need no Marketplace review.

## Apply a Prism release

1. Download `prism-tokens-webflow.zip` from the new release. Upload it with **Publish extension version** (step 2 above). Each upload is a new version of the app.
2. Open the site in the Designer, on its main branch, in Design mode. Press **E** to open the Apps panel, find Prism tokens and click **Launch App**. ("Launch development app" is for Prism developers.)
3. The panel shows the Prism version and the collection it will write to. It lists what it will do: **To update**, **To add**, **Unchanged** and **Skipped**, with the reason for each skipped token.
4. Click **Apply Prism's tokens**. The panel then lists what it did, and the button stays off. To run it again, close the app and launch it again: everything then shows as unchanged.

## What it changes

- **Which collection:** the one that already holds the most variables with Prism's names, such as the hand copy of primary, secondary, tertiary and grey 1–6. If no collection has any, it uses the site's default collection. If two collections are tied, it changes nothing and tells you so.
- **Existing variables:** it matches names without regard to case, spaces or dashes, so the site's `Grey 1` is Prism's `grey1`. It sets the value and keeps your name. Styles bound to the variable follow the new value.
- **New variables:**
  - Colors get Prism's name: `primarylight`, `success` and so on.
  - Every other token goes in a folder named after its kind: `font-family/display`, `font-weight/title0` (a number variable), `font-size/title0`, `line-height/title0`, `spacing/15`, `height/44px`, `max-height/dropdown` and `radius/default`.
  - `delete` and `deletelight` are aliases of `error` and `errorlight`.
- **Fonts:** a font family variable holds the font's name (`Nunito`, `Nunito Sans`). The site needs those fonts installed (Site settings, then Fonts).
- **Modes:** it sets only the base value; other variable modes keep theirs.
- **Never:** it never removes or renames a variable. If a variable has a Prism name but a different type (say, a number named `primary`), it skips that one and says why.
- **Skipped tokens:** Webflow variables have no type for these, so the extension skips them:
  - typography, the combinations of family, weight, size and line height (Prism's `typography.title0`). Build them as text styles from the four variables they combine.
  - shadows and text shadows.
  - Prism's 50% radius, which isn't in Prism's token file.
- **Permissions:** you need a site role that may change variables, such as Site manager or Designer. If Webflow refuses a change, that token is listed as skipped with Webflow's message.
