const raycastConfig = require("@raycast/eslint-config");

module.exports = [
  {
    ignores: [
      "node_modules/**",
      "dist/**",
      "build/**",
      "coverage/**",
      ".raycast/**",
      "PageForge/**",
      "PageForgeTests/**",
      "legacy/**",
    ],
  },
  ...raycastConfig,
];
