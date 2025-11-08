import { Link } from 'react-router-dom'

export default function Navigation() {
  return (
    <nav className="bg-white shadow">
      <div className="container mx-auto px-4 py-4 flex justify-between items-center">
        <h1 className="text-2xl font-bold text-blue-600">Pivori Studio</h1>
        <ul className="flex gap-6">
          <li><Link to="/" className="hover:text-blue-600">Dashboard</Link></li>
          <li><Link to="/services" className="hover:text-blue-600">Services</Link></li>
          <li><Link to="/settings" className="hover:text-blue-600">Settings</Link></li>
        </ul>
      </div>
    </nav>
  )
}
