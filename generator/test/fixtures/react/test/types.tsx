// Type checks of the generated components: `npm run check` fails when a line
// marked @ts-expect-error compiles, so TypeScript rejects what the design doesn't have.
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
