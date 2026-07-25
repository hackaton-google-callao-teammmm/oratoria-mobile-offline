/**
 * App sidebar — responsive, collapsible, accessible.
 *
 * - Desktop (lg+): static rail, collapsible to icons-only (preference
 *   persisted). Mobile: off-canvas drawer toggled from the topbar, with
 *   an overlay, Escape-to-close and `inert` background (handled by the
 *   layout).
 * - Active item derives from the router and is marked `aria-current`.
 * - Real routes link; not-yet-built sections are shown disabled.
 */
import { Link, useRouterState } from "@tanstack/react-router";
import {
  Clock,
  Home,
  Mic,
  PanelLeft,
  Settings,
  Target,
  Trophy,
  X,
  type LucideIcon,
} from "lucide-react";
import { useEffect } from "react";

import { cn, initialsOf, namePartOfEmail } from "@/lib/utils";
import { useDashboardData } from "@/lib/dashboard/use-dashboard-data";
import {
  computeAchievements,
  countUnlocked,
} from "@/lib/progress/achievements";
import { useUiStore } from "@/stores/ui-store";
import type { User } from "@/lib/api/schemas";

interface NavItem {
  label: string;
  icon: LucideIcon;
  to?: string;
  match?: (pathname: string) => boolean;
  badge?: string;
  soon?: boolean;
}

const MAIN_NAV: NavItem[] = [
  {
    label: "Inicio",
    icon: Home,
    to: "/dashboard",
    match: (p) => p === "/dashboard",
  },
  {
    label: "Nueva sesión",
    icon: Mic,
    to: "/practice/new",
    match: (p) => p.startsWith("/practice"),
  },
  {
    label: "Mi progreso",
    icon: Target,
    to: "/progress",
    match: (p) => p.startsWith("/progress"),
  },
  {
    label: "Histórico",
    icon: Clock,
    to: "/history",
    match: (p) => p.startsWith("/history"),
  },
  {
    label: "Logros",
    icon: Trophy,
    to: "/achievements",
    match: (p) => p.startsWith("/achievements"),
  },
];

const ACCOUNT_NAV: NavItem[] = [
  { label: "Configuración", icon: Settings, soon: true },
];

export function Sidebar({ user }: { user: User }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const mobileNavOpen = useUiStore((s) => s.mobileNavOpen);
  const closeMobileNav = useUiStore((s) => s.closeMobileNav);
  const collapsed = useUiStore((s) => s.collapsed);
  const toggleCollapsed = useUiStore((s) => s.toggleCollapsed);

  // Escape closes the mobile drawer.
  useEffect(() => {
    if (!mobileNavOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeMobileNav();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [mobileNavOpen, closeMobileNav]);

  const displayName = user.full_name ?? namePartOfEmail(user.email);

  // Live badges from the shared (cached) sessions query: history count and
  // unlocked-achievements count. Falls back to no badge while loading.
  const data = useDashboardData();
  const unlockedCount = data.loading
    ? 0
    : countUnlocked(
        computeAchievements({
          sessions: data.sessions,
          completedSessions: data.completedSessions,
          streakDays: data.streakDays,
          practicedSeconds: data.practicedSeconds,
        }),
      );
  const badgeByLabel: Record<string, string | undefined> = {
    Histórico:
      data.loading || data.totalSessions === 0
        ? undefined
        : String(data.totalSessions),
    Logros: unlockedCount > 0 ? String(unlockedCount) : undefined,
  };
  const mainNav = MAIN_NAV.map((item) =>
    item.label in badgeByLabel
      ? { ...item, badge: badgeByLabel[item.label] }
      : item,
  );

  return (
    <>
      {/* Overlay (mobile only) */}
      <div
        aria-hidden
        onClick={closeMobileNav}
        className={cn(
          "fixed inset-0 z-40 bg-black/50 backdrop-blur-sm transition-opacity duration-300 lg:hidden",
          mobileNavOpen ? "opacity-100" : "pointer-events-none opacity-0",
        )}
      />

      <aside
        id="app-sidebar"
        aria-label="Navegación principal"
        className={cn(
          "fixed inset-y-0 left-0 z-50 flex w-72 -translate-x-full flex-col border-r border-line bg-stage transition-[transform,width] duration-300 ease-out",
          mobileNavOpen && "translate-x-0",
          "lg:static lg:translate-x-0",
          collapsed ? "lg:w-[76px]" : "lg:w-64",
        )}
      >
        {/* Header: brand + close (mobile) */}
        <div className="flex h-16 shrink-0 items-center justify-between gap-2 px-4">
          <Link
            to="/dashboard"
            onClick={closeMobileNav}
            aria-label="OratorIA — Inicio"
            className="flex items-center"
          >
            <img
              src="/OratorIA-lockup.svg"
              alt="OratorIA"
              className={cn("h-7", collapsed && "lg:hidden")}
            />
            <img
              src="/OratorIA-isotype.svg"
              alt=""
              className={cn("hidden h-8 w-8", collapsed && "lg:block")}
            />
          </Link>
          <button
            type="button"
            onClick={closeMobileNav}
            aria-label="Cerrar menú"
            className="grid h-9 w-9 place-items-center rounded-lg text-ink-soft transition-colors hover:bg-surface hover:text-ink lg:hidden"
          >
            <X className="h-5 w-5" strokeWidth={1.8} aria-hidden />
          </button>
        </div>

        <div className="flex min-h-0 flex-1 flex-col gap-1 overflow-y-auto px-3 pb-4">
          <UserPill name={displayName} plan={user.plan} collapsed={collapsed} />

          <nav aria-label="Principal" className="mt-2">
            <GroupLabel collapsed={collapsed}>Principal</GroupLabel>
            <ul className="flex flex-col gap-0.5">
              {mainNav.map((item) => (
                <li key={item.label}>
                  <NavLinkItem
                    item={item}
                    active={item.match?.(pathname) ?? false}
                    collapsed={collapsed}
                    onNavigate={closeMobileNav}
                  />
                </li>
              ))}
            </ul>
          </nav>

          <nav aria-label="Cuenta" className="mt-4">
            <GroupLabel collapsed={collapsed}>Cuenta</GroupLabel>
            <ul className="flex flex-col gap-0.5">
              {ACCOUNT_NAV.map((item) => (
                <li key={item.label}>
                  <NavLinkItem
                    item={item}
                    active={false}
                    collapsed={collapsed}
                    onNavigate={closeMobileNav}
                  />
                </li>
              ))}
            </ul>
          </nav>

          <div className="mt-auto pt-4">
            <UpgradeCard plan={user.plan} collapsed={collapsed} />
          </div>
        </div>

        {/* Collapse toggle (desktop only) */}
        <button
          type="button"
          onClick={toggleCollapsed}
          aria-label={
            collapsed ? "Expandir barra lateral" : "Colapsar barra lateral"
          }
          aria-expanded={!collapsed}
          className={cn(
            "hidden h-12 shrink-0 items-center gap-3 border-t border-line px-5 text-[13px] font-medium text-ink-soft transition-colors hover:text-ink lg:flex",
            collapsed && "lg:justify-center lg:px-0",
          )}
        >
          <PanelLeft
            className={cn(
              "h-5 w-5 shrink-0 transition-transform",
              collapsed && "rotate-180",
            )}
            strokeWidth={1.8}
            aria-hidden
          />
          <span className={cn(collapsed && "lg:hidden")}>Colapsar</span>
        </button>
      </aside>
    </>
  );
}

function GroupLabel({
  collapsed,
  children,
}: {
  collapsed: boolean;
  children: React.ReactNode;
}) {
  return (
    <div
      className={cn(
        "px-3 pb-2 pt-1 text-[10px] font-semibold uppercase tracking-[0.16em] text-ink-faint",
        collapsed && "lg:hidden",
      )}
    >
      {children}
    </div>
  );
}

function NavLinkItem({
  item,
  active,
  collapsed,
  onNavigate,
}: {
  item: NavItem;
  active: boolean;
  collapsed: boolean;
  onNavigate: () => void;
}) {
  const Icon = item.icon;
  const className = cn(
    "group flex min-h-[44px] items-center gap-3 rounded-lg px-3 text-[14px] font-medium transition-colors",
    collapsed && "lg:justify-center lg:px-0",
    active && "bg-surface font-semibold text-ink ring-1 ring-line",
    !active && !item.soon && "text-ink-soft hover:bg-surface hover:text-ink",
    item.soon && "cursor-not-allowed text-ink-faint/70",
  );

  const inner = (
    <>
      <Icon
        className={cn("h-5 w-5 shrink-0", active && "text-accent")}
        strokeWidth={1.8}
        aria-hidden
      />
      <span className={cn("flex-1 truncate", collapsed && "lg:hidden")}>
        {item.label}
      </span>
      {item.badge && (
        <span
          className={cn(
            "rounded-md bg-surface-2 px-1.5 py-0.5 text-[10px] font-semibold text-ink-soft",
            active && "bg-lime text-on-lime",
            collapsed && "lg:hidden",
          )}
        >
          {item.badge}
        </span>
      )}
      {item.soon && (
        <span
          className={cn(
            "rounded-full bg-surface-2 px-2 py-0.5 text-[9px] font-semibold uppercase tracking-wider text-ink-faint",
            collapsed && "lg:hidden",
          )}
        >
          Pronto
        </span>
      )}
    </>
  );

  if (item.soon || !item.to) {
    return (
      <span
        className={className}
        aria-disabled="true"
        title={collapsed ? `${item.label} (próximamente)` : undefined}
      >
        {inner}
      </span>
    );
  }

  return (
    <Link
      to={item.to}
      onClick={onNavigate}
      aria-current={active ? "page" : undefined}
      title={collapsed ? item.label : undefined}
      className={className}
    >
      {inner}
    </Link>
  );
}

function UserPill({
  name,
  plan,
  collapsed,
}: {
  name: string;
  plan: User["plan"];
  collapsed: boolean;
}) {
  return (
    <div
      className={cn(
        "flex items-center gap-2.5 rounded-xl border border-line bg-surface p-2.5",
        collapsed && "lg:justify-center lg:border-0 lg:bg-transparent lg:p-1",
      )}
    >
      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-lime text-xs font-bold text-on-lime">
        {initialsOf(name)}
      </span>
      <span className={cn("min-w-0 flex-1", collapsed && "lg:hidden")}>
        <span className="block truncate text-[13px] font-semibold text-ink">
          {name}
        </span>
        <span className="block text-[11px] capitalize text-ink-faint">
          Plan {plan}
        </span>
      </span>
    </div>
  );
}

function UpgradeCard({
  plan,
  collapsed,
}: {
  plan: User["plan"];
  collapsed: boolean;
}) {
  if (plan !== "free") return null;
  return (
    <div
      className={cn(
        "overflow-hidden rounded-xl border border-line bg-surface p-4",
        collapsed && "lg:hidden",
      )}
    >
      <p className="text-xs text-ink-soft">2 de 3 sesiones usadas este mes.</p>
      <h4 className="mt-1.5 text-sm font-semibold text-ink">
        Sesiones ilimitadas con Pro
      </h4>
      <button
        type="button"
        className="mt-3 w-full rounded-lg bg-lime px-3 py-2 text-xs font-bold text-on-lime transition-colors hover:bg-lime-dim"
      >
        Mejorar a Pro
      </button>
    </div>
  );
}
