import assert from "node:assert/strict";
import { test } from "node:test";
import { textFieldInputMetadata } from "../dist/index.js";

test("neutral design metadata preserves its own bounds and disabled default", () => {
  assert.deepEqual(textFieldInputMetadata(), { settleMs: null });
  assert.deepEqual(textFieldInputMetadata({ settleMs: null }), { settleMs: null });
  for (const value of [1, 500, 1000]) {
    assert.deepEqual(textFieldInputMetadata({ settleMs: value }), { settleMs: value });
  }
  for (const value of [0, -1, 1001, 1.5, true, "500", NaN, Infinity]) {
    assert.throws(() => textFieldInputMetadata({ settleMs: value }), /integer milliseconds/);
  }
});
