import { useEffect, useState } from "react";
import { api } from "../../api";
import { ETHOS_MARK } from "../../ui/Icon";
import "./splash.css";

/** When the window grows: the animation settles at 3 s (79% of 3.8 s), then holds 2 s. */
const GROW_MS = 3000 + 2000;
/** Set once the splash has run: a webview reload doesn't play it again. */
const KEY = "roalt.splash";

function Tile({ className, fill }: { className: string; fill: string }) {
  return (
    <svg className={className} width="120" height="120" viewBox="-20 -20 160 160" aria-hidden="true">
      <path fill={fill} d={ETHOS_MARK} />
    </svg>
  );
}

function seen() {
  // Settings.skip_splash, from `main_window`: the window is already full size.
  if ((window as { __ROALT_SKIP_SPLASH?: boolean }).__ROALT_SKIP_SPLASH) return true;
  try {
    return sessionStorage.getItem(KEY) !== null;
  } catch {
    return false;
  }
}

/** The start-up splash over the app: the Ethos mark glitches in, then the window
 * (opened small by `splash::start`) grows into the app and this fades away. */
export function Splash() {
  const [state, setState] = useState<"play" | "out" | "gone">(() => (seen() ? "gone" : "play"));

  useEffect(() => {
    if (state !== "play") return;
    // Plays even with Windows' animation effects off (theme.css leaves the splash out).
    const grow = () => {
      try {
        sessionStorage.setItem(KEY, "1");
      } catch {
        // No storage: a reload plays it again.
      }
      // Fades once the window has grown, even if growing failed.
      api.splashDone().finally(() => setState("out"));
    };
    const t = setTimeout(grow, GROW_MS);
    return () => clearTimeout(t);
  }, [state]);

  if (state === "gone") return null;
  return (
    <div
      className={`splash ${state === "out" ? "out" : ""}`}
      data-tauri-drag-region
      onTransitionEnd={(e) => e.target === e.currentTarget && setState("gone")}
      aria-hidden="true"
    >
      <div className="mark" data-tauri-drag-region>
        <div className="logo">
          <div className="tile">
            <Tile className="red" fill="#ff2a4d" />
            <Tile className="cyan" fill="#22e8ff" />
            <Tile className="core" fill="#eceef1" />
            <Tile className="slice-a" fill="#eceef1" />
            <Tile className="slice-b" fill="#22e8ff" />
          </div>
        </div>
      </div>
      <div className="mark">
        <div className="word">
          <b>ETHOS MANAGER</b>
          <span>v{import.meta.env.APP_VERSION}</span>
        </div>
      </div>
      <div className="scan" />
    </div>
  );
}
