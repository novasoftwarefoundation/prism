import { textFieldInputMetadata, textAreaInputMetadata,
  type TextFieldInputMetadata, type TextAreaInputMetadata } from "../src/index.js";

const disabled: TextFieldInputMetadata = {};
const enabled: TextAreaInputMetadata = { autoSubmitDelayMs: 500 };
textFieldInputMetadata(disabled);
textAreaInputMetadata(enabled);
textFieldInputMetadata({ autoSubmitDelayMs: null });
// @ts-expect-error a numeric string is not metadata milliseconds
textFieldInputMetadata({ autoSubmitDelayMs: "500" });
// @ts-expect-error a boolean is not metadata milliseconds
textAreaInputMetadata({ autoSubmitDelayMs: true });
