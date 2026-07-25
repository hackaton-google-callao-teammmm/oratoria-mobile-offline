import { Bell, ChevronDown, LogOut, Menu, Search } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { ThemeToggle } from "@/components/dashboard/theme-toggle";
import type { User } from "@/lib/api/schemas";
import { initialsOf, namePartOfEmail } from "@/lib/utils";
import { useAuthStore } from "@/stores/auth-store";
import { useUiStore } from "@/stores/ui-store";

interface TopbarProps {
  user: User;
  crumb?: string;
}

export function Topbar({ user, crumb = "Inicio" }: TopbarProps) {
  const displayName = user.full_name ?? namePartOfEmail(user.email);
  const firstName = displayName.split(" ")[0] ?? displayName;
  const openMobileNav = useUiStore((s) => s.openMobileNav);
  const mobileNavOpen = useUiStore((s) => s.mobileNavOpen);
  const toggleCollapsed = useUiStore((s) => s.toggleCollapsed);

  // Classic hamburger: collapses/expands the rail on desktop, opens the
  // drawer on mobile.
  const handleMenu = () => {
    if (
      typeof window !== "undefined" &&
      window.matchMedia("(min-width: 1024px)").matches
    ) {
      toggleCollapsed();
    } else {
      openMobileNav();
    }
  };

  return (
    <header className="flex h-16 shrink-0 items-center gap-3 border-b border-line bg-stage px-4 sm:gap-5 sm:px-6 lg:px-8">
      <button
        type="button"
        onClick={handleMenu}
        aria-label="Alternar barra lateral"
        aria-controls="app-sidebar"
        aria-expanded={mobileNavOpen}
        className="grid h-9 w-9 shrink-0 place-items-center rounded-lg text-ink-soft transition-colors hover:bg-surface hover:text-ink"
      >
        <Menu className="h-5 w-5" strokeWidth={1.8} aria-hidden />
      </button>

      <div className="hidden text-[13px] font-medium text-ink-faint sm:block">
        <strong className="font-semibold text-ink">{crumb}</strong>
      </div>

      <div className="relative hidden max-w-sm flex-1 md:block">
        <Search
          className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-faint"
          aria-hidden
        />
        <input
          type="search"
          aria-label="Buscar en tus sesiones"
          placeholder="Buscar en tus sesiones…"
          className="h-9 w-full rounded-lg border border-line bg-surface pl-9 pr-12 text-[13px] text-ink placeholder:text-ink-faint outline-none transition-colors focus:border-lime/50 focus:ring-2 focus:ring-lime/15"
        />
        <kbd className="absolute right-2 top-1/2 -translate-y-1/2 rounded border border-line bg-stage px-1.5 py-0.5 font-mono text-[10px] text-ink-faint">
          ⌘K
        </kbd>
      </div>

      <div className="ml-auto flex items-center gap-2 sm:gap-3">
        <ThemeToggle />
        <button
          type="button"
          aria-label="Notificaciones"
          className="relative grid h-9 w-9 place-items-center rounded-lg border border-line bg-surface text-ink-soft transition-colors hover:bg-surface-2 hover:text-ink"
          title="Próximamente"
        >
          <Bell className="h-4 w-4" strokeWidth={1.8} />
          <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full border-2 border-stage bg-accent" />
        </button>

        <UserMenu name={firstName} initials={initialsOf(displayName)} />
      </div>
    </header>
  );
}

function UserMenu({ name, initials }: { name: string; initials: string }) {
  const logout = useAuthStore((s) => s.logout);
  const [open, setOpen] = useState(false);
  const wrap = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onClick = (e: MouseEvent) => {
      if (wrap.current && !wrap.current.contains(e.target as Node)) setOpen(false);
    };
    window.addEventListener("mousedown", onClick);
    return () => window.removeEventListener("mousedown", onClick);
  }, [open]);

  return (
    <div ref={wrap} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="flex items-center gap-2 rounded-full border border-line bg-surface py-1 pl-1 pr-3 transition-colors hover:bg-surface-2"
      >
        <span className="grid h-7 w-7 place-items-center rounded-full bg-lime text-[10px] font-bold text-on-lime">
          {initials}
        </span>
        <span className="text-[13px] font-semibold text-ink">{name}</span>
        <ChevronDown className="h-3.5 w-3.5 text-ink-faint" />
      </button>

      {open && (
        <div className="absolute right-0 top-[calc(100%+6px)] z-30 w-44 overflow-hidden rounded-lg border border-line bg-surface shadow-xl shadow-black/40">
          <button
            type="button"
            onClick={() => {
              logout();
              window.location.href = "/login";
            }}
            className="flex w-full items-center gap-2 px-3 py-2.5 text-left text-[13px] font-semibold text-ink-soft transition-colors hover:bg-surface-2 hover:text-ink"
          >
            <LogOut className="h-4 w-4" strokeWidth={1.8} />
            Cerrar sesión
          </button>
        </div>
      )}
    </div>
  );
}
