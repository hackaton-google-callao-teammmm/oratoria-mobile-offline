export function AuthDivider({ children }: { children: React.ReactNode }) {
  return (
    <div className="my-6 flex items-center gap-3 text-xs font-medium uppercase tracking-wider text-ink-faint">
      <div className="h-px flex-1 bg-line" />
      <span>{children}</span>
      <div className="h-px flex-1 bg-line" />
    </div>
  );
}
