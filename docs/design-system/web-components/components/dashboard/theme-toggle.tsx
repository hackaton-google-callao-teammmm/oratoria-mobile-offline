import { Moon, Sun } from "lucide-react";
import { useEffect, useState } from "react";

type Theme = "light" | "dark";

function currentTheme(): Theme {
  if (typeof document === "undefined") return "dark";
  return document.documentElement.classList.contains("dark") ? "dark" : "light";
}

export function ThemeToggle() {
  // Server and first client render assume the documented default (dark);
  // the post-mount effect reconciles with whatever the no-flash script set.
  const [theme, setTheme] = useState<Theme>("dark");

  useEffect(() => {
    setTheme(currentTheme());
  }, []);

  const toggle = () => {
    const next: Theme = theme === "dark" ? "light" : "dark";
    setTheme(next);
    document.documentElement.classList.toggle("dark", next === "dark");
    try {
      localStorage.setItem("oratoria-theme", next);
    } catch {
      /* localStorage unavailable — theme still applies for this session */
    }
  };

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={theme === "dark" ? "Activar modo claro" : "Activar modo oscuro"}
      title={theme === "dark" ? "Modo claro" : "Modo oscuro"}
      className="grid h-9 w-9 place-items-center rounded-lg border border-line bg-surface text-ink-soft transition-colors hover:bg-surface-2 hover:text-ink"
    >
      <Sun className="hidden h-4 w-4 dark:block" strokeWidth={1.8} />
      <Moon className="h-4 w-4 dark:hidden" strokeWidth={1.8} />
    </button>
  );
}
