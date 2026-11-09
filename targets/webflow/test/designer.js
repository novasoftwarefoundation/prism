// A fake of the Designer API's variables, as @webflow/designer-extension-typings 2.2.2
// declares them and developers.webflow.com/designer/reference describes them: a
// collection's variables, their names and base values, the create methods per type,
// and the app mode that allows changing variables. It records every write.

let ids = 0;

class Variable {
  constructor(collection, type, name, value) {
    this.id = `variable-${++ids}`;
    this.type = type;
    this.collection = collection;
    this.name = name;
    this.value = value;
  }
  async getName() {
    return this.name;
  }
  async setName(name) {
    this.collection.writes.push(["setName", this.name, name]);
    this.name = name;
    return null;
  }
  // "Calling variable.get() without customValues: true will throw an error if the
  // variable has a custom value."
  async get({ customValues = false } = {}) {
    if (this.value?.type === "custom" && !customValues) throw new Error("custom value");
    return this.value;
  }
  async set(value) {
    if (value instanceof Variable && value.type !== this.type) throw new Error("an alias must be of the same type");
    this.collection.writes.push(["set", this.name, value instanceof Variable ? { alias: value.name } : value]);
    this.value = value;
    return null;
  }
  async remove() {
    this.collection.writes.push(["remove", this.name]);
    this.collection.variables.splice(this.collection.variables.indexOf(this), 1);
    return true;
  }
}

export class Collection {
  constructor(name, variables = []) {
    this.id = `collection-${name}`;
    this.name = name;
    this.writes = [];
    this.variables = variables.map(([type, name, value]) => new Variable(this, type, name, value));
  }
  async getName() {
    return this.name;
  }
  async getAllVariables() {
    return [...this.variables];
  }
  async getVariableByName(name) {
    return this.variables.find((v) => v.name === name) ?? null;
  }
  // A variable by its name, for the tests.
  variable(name) {
    return this.variables.find((v) => v.name === name);
  }
  #create(type, name, value) {
    if (this.variables.some((v) => v.name === name)) throw new Error(`a variable named ${name} exists`);
    const variable = new Variable(this, type, name, value);
    this.writes.push(["create", type, name, value instanceof Variable ? { alias: value.name } : value]);
    this.variables.push(variable);
    return variable;
  }
  async createColorVariable(name, value) {
    return this.#create("Color", name, value);
  }
  async createSizeVariable(name, value) {
    return this.#create("Size", name, value);
  }
  async createNumberVariable(name, value) {
    return this.#create("Number", name, value);
  }
  async createPercentageVariable(name, value) {
    return this.#create("Percentage", name, value);
  }
  async createFontFamilyVariable(name, value) {
    return this.#create("FontFamily", name, value);
  }
}

// The `webflow` global for a site with these collections, the first being its
// default; `canModifyVariables` is false outside Design mode or on a branch.
export function designer(collections, { canModifyVariables = true } = {}) {
  return {
    appModes: { canModifyVariables: "canModifyVariables" },
    async canForAppMode(modes) {
      return Object.fromEntries(modes.map((mode) => [mode, mode === "canModifyVariables" && canModifyVariables]));
    },
    async getDefaultVariableCollection() {
      return collections[0] ?? null;
    },
    async getAllVariableCollections() {
      return [...collections];
    },
  };
}
