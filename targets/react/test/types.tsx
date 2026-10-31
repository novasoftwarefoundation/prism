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
    <Spinner size="large" variant="inverse" />
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

// @ts-expect-error: 0.1.7's names are gone
export const oldName = <Button variant="label">Save</Button>;

// @ts-expect-error: danger is the red tone, error is no tone
export const errorTone = <Tag tone="error">Failed</Tag>;
