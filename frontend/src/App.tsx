import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Dashboard from './pages/Dashboard'
import Services from './pages/Services'
import Settings from './pages/Settings'
import Navigation from './components/Navigation'

function App() {
  return (
    <BrowserRouter>
      <div className="min-h-screen bg-gray-50">
        <Navigation />
        <main className="container mx-auto py-8">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/services" element={<Services />} />
            <Route path="/settings" element={<Settings />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  )
}

export default App
