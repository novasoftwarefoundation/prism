// Type checks: `npm run check` fails when a line expected to be an error (the
// directive above it) compiles, so TypeScript rejects what Prism's design doesn't have.
import { Button, Field, Spinner, Tag, TextField } from "../src/index.js";

export const accepted = (
  <>
    <Button variant="primary" tone="danger" loading icon={<span />} onClick={() => {}}>
      Save
    </Button>
    <Button as="a" href="/next" variant="link">
      Next
    </Button>
    <Field label="Email" labelProps={{ htmlFor: "email" }} errorMessage="Required">
      <TextField id="email" invalid />
    </Field>
    <Spinner size={32} variant="inverse" />
    <Spinner size={20} progress={40} />
    <Spinner progress={null} />
    <Tag tone="neutral">Draft</Tag>
  </>
);

// The example in the README.
const CheckIcon = () => <span className="icon-check" />;

export function Profile({
  saving,
  errors,
  onSave,
}: {
  saving: boolean;
  errors: string[];
  onSave: () => void;
}) {
  return (
    <form>
      <Field label="Email" labelProps={{ htmlFor: "email" }} errorMessage={errors[0]}>
        <TextField id="email" name="email" invalid={errors.length > 0} />
      </Field>

      <Button
        variant="primary"
        tone="danger"
        loading={saving}
        icon={<CheckIcon />}
        onClick={onSave}
      >
        Save
      </Button>

      <Tag tone="success">Done</Tag>
    </form>
  );
}

// @ts-expect-error: no such variant
export const unknownVariant = <Button variant="primray">Save</Button>;

// @ts-expect-error: a side is start or end, never left
export const leftIcon = <Button iconPosition="left">Back</Button>;

// The new looks: soft, icon, the neutral and highlight tones, padded and the icon's side.
export const looks = (
  <>
    <Button variant="soft" tone="danger">
      Delete
    </Button>
    <Button variant="icon" icon={<span />} aria-label="Close" />
    <Button variant="primary" tone="neutral">
      Sign in
    </Button>
    <Button variant="primary" tone="highlight">
      Try it
    </Button>
    <Button variant="plain" padded={false} iconPosition="end" icon={<span />}>
      Next
    </Button>
  </>
);

// @ts-expect-error: 0.1.7's names are gone
export const oldName = <Button variant="label">Save</Button>;

// @ts-expect-error: 0.2.0's sizes are their px: no small, medium or large
export const namedSize = <Spinner size="large" />;

// @ts-expect-error: no such size
export const unknownSize = <Spinner size={18} />;

// @ts-expect-error: the progress is a number
export const progressAsText = <Spinner progress="40" />;

// @ts-expect-error: danger is the red tone, error is no tone
export const errorTone = <Tag tone="error">Failed</Tag>;

// @ts-expect-error: without `as`, a button refuses a link's attributes
export const hrefWithoutAs = <Button href="/next">Next</Button>;

// @ts-expect-error: the same for any attribute only another element has
export const targetWithoutAs = <Button target="_blank">Next</Button>;

// A button's own attributes still work without `as`, and a link's with `as="a"`.
export const ownAttributes = (
  <>
    <Button type="submit" form="profile">
      Save
    </Button>
    <Button as="a" href="/next" target="_blank" rel="noopener">
      Next
    </Button>
  </>
);
