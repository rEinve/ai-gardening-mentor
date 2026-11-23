import { defineConfig } from "vite";
import htmlInclude from "vite-plugin-include-html";
import path from "node:path";
import { fileURLToPath } from "node:url";
import fs from "node:fs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const htmlEntries = {};
function collectHtmlEntries(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.isDirectory() && [".git", "dist", "node_modules", "partials"].includes(entry.name)) continue;
    const filePath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      collectHtmlEntries(filePath);
    } else if (entry.isFile() && entry.name.endsWith(".html")) {
      const relativePath = path.relative(__dirname, filePath).replaceAll(path.sep, "/");
      htmlEntries[relativePath.replace(/\.html$/i, "")] = filePath;
    }
  }
}
collectHtmlEntries(__dirname);

export default defineConfig({
  plugins: [
    htmlInclude(),
    {
      name: "watch-partials",
      configureServer(server) {
        server.watcher.add(path.resolve(__dirname, "partials"));
        server.watcher.on("change", (file) => {
          if (file.includes(`${path.sep}partials${path.sep}`)) {
            server.ws.send({ type: "full-reload", path: "*" });
          }
        });
      },
    },
    {
      name: "watch-html",
      configureServer(server) {
        server.watcher.add(path.resolve(__dirname, "*.html"));
        server.watcher.on("change", (file) => {
          if (file.endsWith(".html")) {
            server.ws.send({ type: "full-reload", path: "*" });
          }
        });
      },
    },
  ],
  resolve: {
    alias: {
      "themeui-lab/src/scss/abstracts/mixins": path.resolve(
        __dirname,
        "node_modules/themeui-lab/src/scss/abstracts/mixins"
      ),
    },
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
    manifest: true,
    rollupOptions: {
      input: htmlEntries,
      output: {
        entryFileNames: "assets/js/main.js",
        chunkFileNames: "assets/js/[name]-[hash].js",
        assetFileNames: (assetInfo) => {
          const name = assetInfo.name ?? "";
          if (name.endsWith(".css")) return "assets/css/main.css";
          if (/\.(png|jpe?g|gif|svg|webp|avif)$/i.test(name)) return "assets/images/[name][extname]";
          if (/\.(woff|woff2|eot|ttf|otf)$/i.test(name)) return "assets/fonts/[name][extname]";
          return "assets/[name][extname]";
        },
      },
    },
  },
  css: {
    // Preserve Sass origins in browser DevTools so resolved theme/button tokens
    // can be traced to their source partials while the prototype is running.
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
    strictPort: true,
    fs: {
      allow: [
        __dirname,
        path.resolve(__dirname, "../../"),
        path.resolve(__dirname, "../../../../"),
      ],
    },
  },
});
