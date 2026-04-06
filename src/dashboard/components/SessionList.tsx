import React, { useState } from "react";
import { removeSession } from "../api";
import { StartSession } from "./StartSession";

interface Session {
  session: string;
  status: "idle" | "busy" | "offline";
  tmux: string;
}

const statusColor: Record<string, string> = {
  idle: "bg-green-500",
  busy: "bg-amber-500",
  offline: "bg-gray-600",
};

export function SessionList({
  sessions,
  selected,
  onSelect,
  onRefresh,
}: {
  sessions: Session[];
  selected: string | null;
  onSelect: (s: string | null) => void;
  onRefresh: () => void;
}) {
  const [showStart, setShowStart] = useState(false);

  return (
    <aside className="w-full md:w-60 border-b md:border-b-0 md:border-r border-gray-800 flex flex-col shrink-0">
      <div className="px-3 py-2 text-xs font-medium text-gray-500 uppercase tracking-wider">
        Sessions
      </div>
      <div className="flex-1 overflow-y-auto">
        {sessions.length === 0 && (
          <p className="px-3 py-4 text-gray-600 text-sm">No sessions</p>
        )}
        {sessions.map((s) => (
          <div
            key={s.session}
            className={`flex items-center gap-2 px-3 py-2 hover:bg-gray-900 transition-colors ${
              s.session === selected ? "bg-gray-900" : ""
            }`}
          >
            <button
              onClick={() => onSelect(s.session === selected ? null : s.session)}
              className="flex items-center gap-2 text-sm text-left flex-1 min-w-0"
            >
              <span className={`w-2 h-2 rounded-full shrink-0 ${statusColor[s.status]}`} />
              <span className="truncate flex-1">{s.session}</span>
              <span className="text-xs text-gray-500">{s.status}</span>
            </button>
            {s.status === "offline" && (
              <button
                onClick={async (e) => {
                  e.stopPropagation();
                  await removeSession(s.session);
                  if (selected === s.session) onSelect(null);
                  onRefresh();
                }}
                className="text-xs text-gray-600 hover:text-red-400 transition-colors shrink-0"
                title="Remove session"
              >
                ×
              </button>
            )}
          </div>
        ))}
      </div>
      <div className="p-2 border-t border-gray-800">
        {showStart ? (
          <StartSession
            onDone={() => { setShowStart(false); onRefresh(); }}
            onCancel={() => setShowStart(false)}
          />
        ) : (
          <button
            onClick={() => setShowStart(true)}
            className="w-full text-xs text-gray-400 hover:text-gray-200 bg-gray-900 hover:bg-gray-800 rounded px-2 py-1.5 transition-colors"
          >
            + Start Session
          </button>
        )}
      </div>
    </aside>
  );
}
