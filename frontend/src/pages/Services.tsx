export default function Services() {
  const services = [
    { name: 'Geolocation', port: 8010, status: 'healthy' },
    { name: 'Routing', port: 8020, status: 'healthy' },
    { name: 'Trading', port: 8040, status: 'healthy' },
  ]

  return (
    <div>
      <h2 className="text-3xl font-bold mb-6">Services</h2>
      <div className="bg-white rounded shadow overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-100">
            <tr>
              <th className="px-6 py-3 text-left">Service</th>
              <th className="px-6 py-3 text-left">Port</th>
              <th className="px-6 py-3 text-left">Status</th>
            </tr>
          </thead>
          <tbody>
            {services.map(s => (
              <tr key={s.port} className="border-t">
                <td className="px-6 py-3">{s.name}</td>
                <td className="px-6 py-3">{s.port}</td>
                <td className="px-6 py-3">
                  <span className="px-3 py-1 bg-green-100 text-green-800 rounded">
                    {s.status}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
