import { defineConfig } from "astro/config";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  vite: {
    resolve: {
      alias: {
        "themeui-lab/src/scss/abstracts/mixins": path.resolve(
          __dirname,
          "node_modules/themeui-lab/src/scss/abstracts/mixins"
        ),
      },
    },
    css: {
      devSourcemap: true,
      preprocessorOptions: {
        scss: {
          api: "modern-compiler",
          sourceMap: true,
          silenceDeprecations: [
            "import",
            "color-functions",
            "global-builtin",
            "legacy-js-api",
          ],
        },
      },
    },
    server: {
      host: "0.0.0.0",
      port: 4344,
      fs: {
        allow: [
          __dirname,
          path.resolve(__dirname, "../../"),
          path.resolve(__dirname, "../../../../"),
        ],
      },
    },
  },
});
