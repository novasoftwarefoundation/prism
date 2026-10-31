// Type checks: `npm run check` fails when a line expected to be an error (the
// directive above it) compiles, so TypeScript rejects what the design doesn't have.
import { Button, Select, Spinner, Tag, TextField } from "../src/index.js";

export const accepted = (
  <>
    <Button variant="subtle" tone="danger" loading icon="*" onClick={() => {}}>
      Save
    </Button>
    <Button as="a" href="/next">
      Next
    </Button>
    <Spinner size="medium" variant="accent" />
    <TextField invalid name="email" />
    <Select options={[{ selected: true, children: "A" }]}>Pick</Select>
  </>
);

// @ts-expect-error: no such variant
export const unknownVariant = <Button variant="primray">Save</Button>;

// @ts-expect-error: no such tone
export const unknownTone = <Tag tone="error">Done</Tag>;

// @ts-expect-error: not an element a button can be
export const unknownElement = <Button as="script">x</Button>;

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
