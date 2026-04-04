# Black Friday Survival — Slides

Présentation Slidev du projet HETIC MT5 Groupe 2.

## Prérequis

- [Node.js](https://nodejs.org/) v18+
- `npm`, `pnpm` ou `yarn`

## Lancer en mode développement

```bash
cd docs/slides
npm install   # ou pnpm install / yarn
npm run dev   # ou pnpm run dev / yarn dev
```

La présentation s'ouvre automatiquement sur http://localhost:3030.

| URL | Description |
|-----|-------------|
| http://localhost:3030 | Slides |
| http://localhost:3030/presenter/ | Mode présentateur (notes) |
| http://localhost:3030/overview/ | Vue d'ensemble |

## Exporter en PDF

```bash
npm run export   # ou pnpm run export / yarn export
```

Génère `slides-export.pdf` dans `docs/slides/`.

> `playwright-chromium` est déjà inclus dans les devDependencies — pas d'installation supplémentaire.

## Build statique (hébergement)

```bash
npm run build   # ou pnpm run build / yarn build
```

Génère un SPA dans `docs/slides/dist/` déployable sur n'importe quel hébergeur statique.