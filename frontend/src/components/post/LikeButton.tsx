"use client";

import { useState, useCallback } from "react";
import { Heart } from "lucide-react";

interface Particle {
  id: number;
  tx: string;
  ty: string;
  emoji: string;
  size: number;
  delay: number;
}

const EMOJIS = ["❤️", "💕", "✨", "💖", "💗"];
const COUNT = 10;

function burst(): Particle[] {
  return Array.from({ length: COUNT }, (_, i) => {
    const angle = (i / COUNT) * 2 * Math.PI + (Math.random() - 0.5) * 0.8;
    const dist = 30 + Math.random() * 30;
    return {
      id: Date.now() + i,
      tx: `${Math.round(Math.cos(angle) * dist)}px`,
      ty: `${Math.round(Math.sin(angle) * dist)}px`,
      emoji: EMOJIS[Math.floor(Math.random() * EMOJIS.length)],
      size: 10 + Math.floor(Math.random() * 8),
      delay: Math.random() * 80,
    };
  });
}

interface Props {
  liked: boolean;
  count: number;
  onClick: () => void;
  disabled?: boolean;
  size?: "sm" | "md";
}

export function LikeButton({ liked, count, onClick, disabled, size = "md" }: Props) {
  const iconSize = size === "sm" ? 13 : 18;
  const textSize = size === "sm" ? "text-xs" : "text-sm";
  const [particles, setParticles] = useState<Particle[]>([]);
  const [popping, setPopping] = useState(false);

  const handleClick = useCallback(() => {
    if (!liked) {
      setParticles(burst());
      setPopping(true);
      setTimeout(() => setParticles([]), 700);
      setTimeout(() => setPopping(false), 400);
    }
    onClick();
  }, [liked, onClick]);

  return (
    <button
      onClick={handleClick}
      disabled={disabled}
      className={`relative flex items-center gap-2 ${textSize} transition-colors ${
        liked ? "text-red-500" : "text-gray-400 hover:text-red-500"
      }`}
    >
      <span className={popping ? "like-pop" : ""}>
        <Heart size={iconSize} className={liked ? "fill-red-500" : ""} />
      </span>
      {count}

      {particles.map((p) => (
        <span
          key={p.id}
          className="like-particle"
          style={
            {
              "--tx": p.tx,
              "--ty": p.ty,
              fontSize: p.size,
              animationDelay: `${p.delay}ms`,
              left: "50%",
              top: "50%",
              marginLeft: -p.size / 2,
              marginTop: -p.size / 2,
            } as React.CSSProperties
          }
        >
          {p.emoji}
        </span>
      ))}
    </button>
  );
}
