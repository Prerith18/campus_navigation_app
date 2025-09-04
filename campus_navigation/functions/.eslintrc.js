module.exports = {
  parserOptions: {
    ecmaVersion: 2020,
  },
  env: {es6: true, node: true},
  extends: ["eslint:recommended", "google"],
  rules: {
    "quotes": ["error", "double"],
    "indent": ["error", 2],
    "object-curly-spacing": ["error", "never"],
    "comma-dangle": ["error", "always-multiline"],
  },
};
