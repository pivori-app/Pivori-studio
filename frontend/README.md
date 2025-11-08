# Pivori Studio Frontend

Production-ready React + TypeScript + Vite frontend for Pivori Studio.

## Tech Stack

- React 18
- TypeScript
- Vite
- Tailwind CSS
- React Router
- Zustand (state management)
- Axios (HTTP client)
- Vitest (testing)

## Development

```bash
npm install
npm run dev
```

Visit http://localhost:5173

## Build

```bash
npm run build
npm run preview
```

## Testing

```bash
npm test
npm run test:ui
```

## Docker

```bash
docker build -t pivori/frontend:1.0.0 .
docker run -p 3000:3000 pivori/frontend:1.0.0
```

## Status

Production-Ready ✅
