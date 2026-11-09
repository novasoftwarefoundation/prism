import { textFieldInputMetadata, textAreaInputMetadata,
  type TextFieldInputMetadata, type TextAreaInputMetadata } from "../src/index.js";

const disabled: TextFieldInputMetadata = {};
const enabled: TextAreaInputMetadata = { debounceMs: 500 };
textFieldInputMetadata(disabled);
textAreaInputMetadata(enabled);
textFieldInputMetadata({ debounceMs: null });
// @ts-expect-error a numeric string is not metadata milliseconds
textFieldInputMetadata({ debounceMs: "500" });
// @ts-expect-error a boolean is not metadata milliseconds
textAreaInputMetadata({ debounceMs: true });
