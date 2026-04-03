import React, { useState } from "react";
import { trigger } from "../api";

export function TriggerForm({ session }: { session: string }) {
  const [prompt, setPrompt] = useState("");
  const [result, setResult] = useState<{ id: string; queued?: boolean } | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!prompt.trim()) return;
    setLoading(true);
    setResult(null);
    try {
      const data = await trigger(session, prompt.trim());
      setResult(data);
      setPrompt("");
    } catch {}
    setLoading(false);
  };

  return (
    <div>
      <h3 className="text-xs font-medium text-gray-500 uppercase tracking-wider mb-2">Send Prompt</h3>
      <form onSubmit={handleSubmit} className="flex gap-2">
        <input
          type="text"
          value={prompt}
          onChange={(e) => { setPrompt(e.target.value); setResult(null); }}
          placeholder="Enter a prompt..."
          className="flex-1 bg-gray-800 border border-gray-700 rounded px-3 py-1.5 text-sm focus:outline-none focus:border-gray-500"
        />
        <button
          type="submit"
          disabled={loading || !prompt.trim()}
          className="bg-gray-700 hover:bg-gray-600 rounded px-4 py-1.5 text-sm font-medium transition-colors disabled:opacity-50 shrink-0"
        >
          {loading ? "..." : "Send"}
        </button>
      </form>
      {result && (
        <p className="text-xs text-gray-500 mt-1.5">
          {result.queued ? `Queued as ${result.id}` : `Sent as ${result.id}`}
        </p>
      )}
    </div>
  );
}
