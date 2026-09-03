const fs = require('node:fs/promises');
const path = require('node:path');
const autoprefixer = require('autoprefixer');
const postcss = require('postcss');
const tailwindcss = require('tailwindcss');

function tailwindPlugin({ config = 'tailwind.config.js' } = {}) {
  const configPath = path.resolve(config);
  const sourceDirectory = path.resolve('src');
  const publicDirectory = path.resolve('public');

  return {
    name: 'tailwindcss',
    setup(build) {
      build.onLoad({ filter: /\.css$/ }, async (args) => {
        const source = await fs.readFile(args.path, 'utf8');
        const result = await postcss([
          tailwindcss({ config: configPath }),
          autoprefixer
        ]).process(source, {
          from: args.path,
          map: false
        });

        return {
          contents: result.css,
          loader: 'css',
          resolveDir: path.dirname(args.path),
          watchDirs: [sourceDirectory, publicDirectory],
          watchFiles: [configPath]
        };
      });
    }
  };
}

module.exports = { tailwindPlugin };
