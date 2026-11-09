import assert from "node:assert/strict";
import { test } from "node:test";
import { textFieldInputMetadata, textAreaInputMetadata } from "../dist/index.js";

for (const validate of [textFieldInputMetadata, textAreaInputMetadata]) {
  test(`${validate.name}: missing/null is disabled; inclusive boundaries are valid`, () => {
    assert.deepEqual(validate(), { autoSubmitDelayMs: null });
    assert.deepEqual(validate({}), { autoSubmitDelayMs: null });
    assert.deepEqual(validate({ autoSubmitDelayMs: null }), { autoSubmitDelayMs: null });
    for (const value of [1, 500, 2147483647]) {
      assert.deepEqual(validate({ autoSubmitDelayMs: value }), { autoSubmitDelayMs: value });
    }
  });

  test(`${validate.name}: reject invalid values without clamping or coercion`, () => {
    for (const value of [0, -1, 2147483648, 1.5, true, false, "500", NaN, Infinity, -Infinity]) {
      assert.throws(() => validate({ autoSubmitDelayMs: value }), /integer milliseconds/);
    }
    for (const value of [null, false, "500", [], 500]) {
      assert.throws(() => validate(value), /must be an object/);
    }
    assert.throws(() => validate({ typo: 500 }), /unknown input property/);
  });
}
