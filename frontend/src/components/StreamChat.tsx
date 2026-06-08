"use client";

import { useChat } from "@livekit/components-react";
import { useState, useRef, useEffect, useCallback } from "react";
import { MessageCircle, Send } from "lucide-react";
import { streamsApi } from "@/lib/api";
import { useAuth } from "@/hooks/useAuth";

interface DbMessage {
  id: string;
  username: string;
  display_name: string;
  message: string;
  created_at: string;
}

interface Props {
  streamId: string;
}

export function StreamChat({ streamId }: Props) {
  const { user } = useAuth();
  const { chatMessages, send } = useChat();
  const [text, setText] = useState("");
  const [history, setHistory] = useState<DbMessage[]>([]);
  const bottomRef = useRef<HTMLDivElement>(null);

  // Load message history from DB on mount (messages sent before joining)
  useEffect(() => {
    if (!streamId) return;
    streamsApi.getMessages(streamId)
      .then((res) => setHistory(res.data.data ?? []))
      .catch(() => {});
  }, [streamId]);

  // Scroll to bottom when messages change
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [history, chatMessages]);

  const handleSend = useCallback(async () => {
    const msg = text.trim();
    if (!msg || !user) return;
    setText("");

    // Send via LiveKit — shows immediately in chatMessages for everyone
    try { await send(msg); } catch { /* ignore */ }

    // Persist to DB for new joiners loading history — do NOT add to local history
    // to avoid duplication with the LiveKit chatMessages entry
    streamsApi.sendMessage(streamId, msg, user.username).catch(() => {});
  }, [text, user, streamId, send]);

  // LiveKit does NOT echo messages back to the sender, so chatMessages
  // only contains messages from OTHER participants — show them all.
  const liveMessages = chatMessages;

  return (
    <div className="flex h-full flex-col">
      <div className="flex flex-shrink-0 items-center gap-2 border-b px-4 py-3 dark:border-gray-700">
        <MessageCircle size={15} className="text-brand-600" />
        <span className="text-sm font-medium">Чат</span>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-3 space-y-2 min-h-0">
        {history.length === 0 && liveMessages.length === 0 && (
          <p className="py-6 text-center text-xs text-gray-400">Сообщений пока нет</p>
        )}

        {/* DB history */}
        {history.map((m) => (
          <div key={m.id} className="text-sm break-words">
            <span className="font-semibold text-brand-600">{m.display_name}</span>
            <span className="text-gray-500">: </span>
            <span className="text-gray-800 dark:text-gray-200">{m.message}</span>
          </div>
        ))}

        {/* LiveKit real-time messages from others */}
        {liveMessages.map((m, i) => (
          <div key={`live-${i}`} className="text-sm break-words">
            <span className="font-semibold text-brand-600">
              {m.from?.name || m.from?.identity || "Аноним"}
            </span>
            <span className="text-gray-500">: </span>
            <span className="text-gray-800 dark:text-gray-200">{m.message}</span>
          </div>
        ))}

        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="flex flex-shrink-0 gap-2 border-t p-3 dark:border-gray-700">
        <input
          className="input flex-1 py-1.5 text-sm"
          placeholder={user ? "Написать сообщение…" : "Войдите чтобы писать"}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && handleSend()}
          disabled={!user}
          maxLength={500}
        />
        <button
          onClick={handleSend}
          disabled={!text.trim() || !user}
          className="flex items-center justify-center rounded-lg bg-brand-600 p-2 text-white transition-colors hover:bg-brand-700 disabled:opacity-40"
        >
          <Send size={14} />
        </button>
      </div>
    </div>
  );
}
