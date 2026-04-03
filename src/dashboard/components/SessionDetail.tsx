import React, { useState, useEffect, useCallback } from "react";
import { getStatus, getQueue, getResponses, getResponse, clearQueue, clearResponses, stopSession, AuthError } from "../api";
import { TriggerForm } from "./TriggerForm";

interface Status {
  status: "idle" | "busy" | "offline";
  since: string;
  currentPrompt?: string;
  currentTaskId?: string;
  queueLength: number;
}

interface QueueItem {
  id: string;
  prompt: string;
  addedAt: string;
  source?: string;
}

interface ResponseItem {
  id: string;
  completed_at: string;
}

function timeAgo(iso: string): string {
  const ms = Date.now() - new Date(iso).getTime();
  if (ms < 0) return "just now";
  const sec = Math.floor(ms / 1000);
  if (sec < 60) return `${sec}s ago`;
  const min = Math.floor(sec / 60);
  if (min < 60) return `${min}m ago`;
  const hrs = Math.floor(min / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

const statusBadge: Record<string, string> = {
  idle: "bg-green-500/20 text-green-400 border-green-500/30",
  busy: "bg-amber-500/20 text-amber-400 border-amber-500/30",
  offline: "bg-gray-500/20 text-gray-400 border-gray-500/30",
};

function ExpandableResponse({ session, id, completedAt }: { session: string; id: string; completedAt: string }) {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState<string[] | null>(null);

  const load = async () => {
    if (messages) { setOpen(!open); return; }
    setOpen(true);
    try {
      const { data } = await getResponse(session, id);
      setMessages(data.messages || []);
    } catch {
      setMessages(["Failed to load response"]);
    }
  };

  return (
    <div className="border-b border-gray-800 last:border-b-0">
      <button onClick={load} className="w-full text-left px-3 py-2 flex items-center gap-3 hover:bg-gray-800/50 transition-colors text-sm">
        <span className="text-gray-400 font-mono text-xs truncate flex-1">{id}</span>
        <span className="text-xs text-gray-600 shrink-0">{timeAgo(completedAt)}</span>
        <span className="text-xs text-gray-600 shrink-0">{open ? "−" : "+"}</span>
      </button>
      {open && messages && (
        <div className="px-3 pb-3">
          {messages.map((msg, i) => (
            <pre key={i} className="text-xs text-gray-300 bg-gray-800 rounded p-2 mt-1 whitespace-pre-wrap break-words overflow-x-auto">
              {msg}
            </pre>
          ))}
        </div>
      )}
    </div>
  );
}

export function SessionDetail({ session, onRefresh }: { session: string; onRefresh: () => void }) {
  const [status, setStatus] = useState<Status | null>(null);
  const [queue, setQueue] = useState<QueueItem[]>([]);
  const [responses, setResponses] = useState<ResponseItem[]>([]);
  const [stopping, setStopping] = useState(false);

  const fetchAll = useCallback(async () => {
    try {
      const [s, q, r] = await Promise.all([
        getStatus(session),
        getQueue(session),
        getResponses(session),
      ]);
      setStatus(s);
      setQueue(q.items || []);
      setResponses(r.items || []);
    } catch (e) {
      if (e instanceof AuthError) throw e;
    }
  }, [session]);

  useEffect(() => {
    fetchAll();
    const id = setInterval(fetchAll, 3000);
    return () => clearInterval(id);
  }, [fetchAll]);

  const handleStop = async () => {
    setStopping(true);
    try {
      await stopSession(session);
      onRefresh();
    } catch {}
    setStopping(false);
  };

  const handleClearQueue = async () => {
    await clearQueue(session);
    fetchAll();
  };

  if (!status) {
    return <div className="flex-1 flex items-center justify-center text-gray-600 text-sm">Loading...</div>;
  }

  return (
    <main className="flex-1 overflow-y-auto p-4 space-y-5">
      {/* Status header */}
      <div className="flex items-start justify-between">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <h2 className="text-base font-semibold">{session}</h2>
            <span className={`text-xs px-2 py-0.5 rounded-full border ${statusBadge[status.status]}`}>
              {status.status}
            </span>
          </div>
          <p className="text-xs text-gray-500">Since {timeAgo(status.since)}</p>
          {status.currentPrompt && (
            <p className="text-sm text-gray-400 mt-1 truncate max-w-lg" title={status.currentPrompt}>
              {status.currentPrompt}
            </p>
          )}
          {status.currentTaskId && (
            <p className="text-xs text-gray-600 font-mono mt-0.5">{status.currentTaskId}</p>
          )}
        </div>
        {status.status !== "offline" && (
          <button
            onClick={handleStop}
            disabled={stopping}
            className="text-xs text-red-400 hover:text-red-300 border border-red-400/30 hover:border-red-400/50 rounded px-2 py-1 transition-colors disabled:opacity-50"
          >
            {stopping ? "Stopping..." : "Stop Session"}
          </button>
        )}
      </div>

      {/* Queue */}
      <div>
        <div className="flex items-center justify-between mb-2">
          <h3 className="text-xs font-medium text-gray-500 uppercase tracking-wider">
            Queue ({queue.length})
          </h3>
          {queue.length > 0 && (
            <button onClick={handleClearQueue} className="text-xs text-gray-500 hover:text-gray-300 transition-colors">
              Clear All
            </button>
          )}
        </div>
        {queue.length === 0 ? (
          <p className="text-xs text-gray-600">Empty</p>
        ) : (
          <div className="bg-gray-900 rounded border border-gray-800">
            {queue.map((item) => (
              <div key={item.id} className="px-3 py-2 border-b border-gray-800 last:border-b-0 flex items-center gap-3 text-sm">
                <span className="text-gray-400 font-mono text-xs truncate flex-1">{item.id}</span>
                <span className="text-gray-300 truncate max-w-48" title={item.prompt}>{item.prompt}</span>
                <span className="text-xs text-gray-600 shrink-0">{timeAgo(item.addedAt)}</span>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Responses */}
      <div>
        <div className="flex items-center justify-between mb-2">
          <h3 className="text-xs font-medium text-gray-500 uppercase tracking-wider">
            Responses ({responses.length})
          </h3>
          {responses.length > 0 && (
            <button onClick={async () => { await clearResponses(session); fetchAll(); }} className="text-xs text-gray-500 hover:text-gray-300 transition-colors">
              Clear All
            </button>
          )}
        </div>
        {responses.length === 0 ? (
          <p className="text-xs text-gray-600">None yet</p>
        ) : (
          <div className="bg-gray-900 rounded border border-gray-800">
            {[...responses]
              .sort((a, b) => new Date(b.completed_at).getTime() - new Date(a.completed_at).getTime())
              .slice(0, 20)
              .map((r) => (
              <ExpandableResponse key={r.id} session={session} id={r.id} completedAt={r.completed_at} />
            ))}
          </div>
        )}
      </div>

      {/* Trigger */}
      {status.status !== "offline" && <TriggerForm session={session} />}
    </main>
  );
}
