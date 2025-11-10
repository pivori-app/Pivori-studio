import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './styles/index.css'
import { initAnalytics } from './services/analytics'

// Initialiser Analytics
try {
  const analyticsKey = import.meta.env.VITE_AMPLITUDE_KEY || 'default-key'
  initAnalytics({
    apiKey: analyticsKey
  })
  console.log('✅ Analytics initialized')
} catch (error) {
  console.error('❌ Failed to initialize analytics:', error)
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
