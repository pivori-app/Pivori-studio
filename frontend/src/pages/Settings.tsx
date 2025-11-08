export default function Settings() {
  return (
    <div>
      <h2 className="text-3xl font-bold mb-6">Settings</h2>
      <div className="bg-white p-6 rounded shadow max-w-md">
        <form className="space-y-4">
          <div>
            <label className="block font-bold mb-2">API URL</label>
            <input type="text" defaultValue="http://localhost:8000" className="w-full border rounded px-3 py-2" />
          </div>
          <div>
            <label className="block font-bold mb-2">Theme</label>
            <select className="w-full border rounded px-3 py-2">
              <option>Light</option>
              <option>Dark</option>
            </select>
          </div>
          <button type="submit" className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
            Save
          </button>
        </form>
      </div>
    </div>
  )
}
