export default function Dashboard() {
  return (
    <div>
      <h2 className="text-3xl font-bold mb-6">Dashboard</h2>
      <div className="grid grid-cols-3 gap-4">
        <div className="bg-white p-6 rounded shadow">
          <h3 className="font-bold">Services</h3>
          <p className="text-2xl text-blue-600">15</p>
        </div>
        <div className="bg-white p-6 rounded shadow">
          <h3 className="font-bold">Healthy</h3>
          <p className="text-2xl text-green-600">15</p>
        </div>
        <div className="bg-white p-6 rounded shadow">
          <h3 className="font-bold">Uptime</h3>
          <p className="text-2xl text-green-600">99.9%</p>
        </div>
      </div>
    </div>
  )
}
