import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  // Home Assistant Ingress serves the app below a dynamic path prefix.
  // Relative asset URLs keep JS/CSS requests inside that prefix.
  base: "./",
});
