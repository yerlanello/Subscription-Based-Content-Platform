"use client";

export function SplashScreen() {
  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 9999,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        background: "#fff",
        gap: "24px",
      }}
    >
      {/* Dog + bubble */}
      <div style={{ position: "relative", display: "inline-block" }}>
        <svg
          width="120"
          height="130"
          viewBox="0 0 120 130"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          className="splash-dog"
        >
          {/* Tail */}
          <path
            d="M85 75 Q108 58 102 42"
            stroke="#c2a06e"
            strokeWidth="7"
            strokeLinecap="round"
            className="splash-tail"
          />
          {/* Body */}
          <ellipse cx="58" cy="82" rx="30" ry="22" fill="#e8c99a" />
          {/* Head */}
          <circle cx="58" cy="50" r="24" fill="#e8c99a" />
          {/* Left ear */}
          <ellipse cx="39" cy="36" rx="10" ry="15" fill="#c2a06e" transform="rotate(-18 39 36)" />
          {/* Right ear */}
          <ellipse cx="77" cy="36" rx="10" ry="15" fill="#c2a06e" transform="rotate(18 77 36)" />
          {/* Muzzle */}
          <ellipse cx="58" cy="57" rx="14" ry="11" fill="#f5deb3" />
          {/* Left eye */}
          <circle cx="50" cy="46" r="4.5" fill="#2d1f14" />
          <circle cx="51.5" cy="44.5" r="1.4" fill="white" />
          {/* Right eye */}
          <circle cx="66" cy="46" r="4.5" fill="#2d1f14" />
          <circle cx="67.5" cy="44.5" r="1.4" fill="white" />
          {/* Nose */}
          <ellipse cx="58" cy="57" rx="4.5" ry="3.5" fill="#b5736b" />
          {/* Mouth */}
          <path d="M54 62 Q58 67 62 62" stroke="#b5736b" strokeWidth="1.8" strokeLinecap="round" fill="none" />
          {/* Front legs */}
          <rect x="40" y="98" width="11" height="20" rx="5.5" fill="#e8c99a" />
          <rect x="67" y="98" width="11" height="20" rx="5.5" fill="#e8c99a" />
        </svg>

        <div className="splash-bubble">
          <span>Хабар!</span>
        </div>
      </div>

      {/* Brand */}
      <p
        className="splash-brand"
        style={{
          fontSize: "26px",
          fontWeight: 800,
          color: "#5b53f5",
          letterSpacing: "0.04em",
          margin: 0,
        }}
      >
        Xabarla
      </p>
    </div>
  );
}
