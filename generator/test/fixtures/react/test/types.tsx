// Type checks: `npm run check` fails when a line expected to be an error (the
// directive above it) compiles, so TypeScript rejects what the design doesn't have.
import { type ComponentProps, createRef } from "react";
import {
  Button,
  type PlainTextAreaProps,
  type RichTextAreaProps,
  Select,
  Spinner,
  Tag,
  TextArea,
  TextField,
} from "../src/index.js";

export const accepted = (
  <>
    <Button variant="subtle" tone="danger" loading icon="*" onClick={() => {}}>
      Save
    </Button>
    <Button as="a" href="/next">
      Next
    </Button>
    <Spinner size={16} variant="accent" />
    <Spinner size={24} progress={40} />
    <Spinner progress={null} />
    <TextField invalid name="email" />
    <Select options={[{ selected: true, children: "A" }]}>Pick</Select>
  </>
);

// A text area with rich text takes the wrapper's props and the app's editor.
export const richText = (
  <TextArea editor="rich_text" invalid id="notes">
    <div className="kit-text-area__editor" />
  </TextArea>
);

// @ts-expect-error: a rich-text text area is disabled by its editor's surface
export const richTextDisabled = <TextArea editor="rich_text" disabled />;

// @ts-expect-error: a textarea's own prop is the editor's with rich text
export const richTextRows = <TextArea editor="rich_text" rows={4} />;

// @ts-expect-error: a plain text area has no content
export const plainChildren = <TextArea>child</TextArea>;

// An app wraps the text area per member of its props, not on the union.
interface LabeledTextAreaProps extends PlainTextAreaProps {
  label: string;
}

export const LabeledTextArea = ({ label, ...rest }: LabeledTextAreaProps) => (
  <label>
    {label}
    <TextArea {...rest} />
  </label>
);

export const WithoutClass = (props: Omit<PlainTextAreaProps, "className">) => (
  <TextArea {...props} className="notes" />
);

export const RichWithoutClass = (props: Omit<RichTextAreaProps, "className">) => (
  <TextArea {...props} className="notes" />
);

export const FewProps = (props: Pick<PlainTextAreaProps, "value" | "onChange" | "invalid">) => (
  <TextArea {...props} />
);

export const MoreRows = (props: Extract<ComponentProps<typeof TextArea>, PlainTextAreaProps>) => (
  <TextArea {...props} rows={3} dirName="notes.dir" />
);

export const PassDisabled = ({ disabled, ...rest }: PlainTextAreaProps) => (
  <TextArea {...rest} disabled={disabled} />
);

// The ref is the textarea's, or with rich text the wrapper <div>'s.
const textareaRef = createRef<HTMLTextAreaElement>();
const divRef = createRef<HTMLDivElement>();

export const plainRef = <TextArea ref={textareaRef} />;

export const richRef = (
  <TextArea editor="rich_text" ref={divRef}>
    <div className="kit-text-area__editor" />
  </TextArea>
);

export const richTextareaRef = (
  // @ts-expect-error: with rich text the ref is the wrapper <div>'s, not a textarea's
  <TextArea editor="rich_text" ref={textareaRef}>
    <div className="kit-text-area__editor" />
  </TextArea>
);

// @ts-expect-error: without rich text the ref is the textarea's
export const plainDivRef = <TextArea ref={divRef} />;

// @ts-expect-error: no such variant
export const unknownVariant = <Button variant="primray">Save</Button>;

// @ts-expect-error: a side is start or end, never left
export const leftIcon = <Button iconPosition="left" icon="*">Back</Button>;

// @ts-expect-error: a flag is a boolean
export const roomyText = <Button roomy="yes">x</Button>;

// The icon's side and the flags.
export const sides = (
  <>
    <Button iconPosition="end" icon="*" roomy={false} strong>
      Next
    </Button>
    <Button variant="icon" icon="*" aria-label="Add" />
  </>
);

// @ts-expect-error: no such size
export const unknownSize = <Spinner size={20} />;

// @ts-expect-error: a size named by a number is a number, not a string
export const sizeAsText = <Spinner size="16" />;

// @ts-expect-error: a value is a number
export const progressAsText = <Spinner progress="40" />;

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
