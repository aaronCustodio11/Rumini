// Editor-only helper: lets VS Code's built-in TypeScript resolve Deno-style
// URL imports (they'd otherwise show ts(2307) "Cannot find module").
// The imported module types resolve to `any` here; the Deno extension (or
// Deno itself at deploy time) checks the real jose package. Harmless to
// deploy — declaration files are never executed.
declare module "https://esm.sh/*";
