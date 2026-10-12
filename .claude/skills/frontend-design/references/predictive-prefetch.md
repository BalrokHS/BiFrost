# Predictive prefetching (opt-in)

**Opt-in recipe.** Use it when navigation feels slow and the person asks for a fix, or when VISION.md asks for it. It adds a dependency, ForesightJS: check `package.json` first and ask before installing it. Next.js already prefetches visible links in production, so the framework default stays unless the person agrees to replace it.

What it does: load the next page while the person is still heading for the link. ForesightJS predicts intent from the cursor's path, from a widened hit area around each link, from keyboard focus coming closer and from scrolling ([ForesightJS settings](https://foresightjs.com/docs/configuration/global-settings/), checked 3 October 2026).

## The rules

- **Path, not hover.** By the time a hover fires, the cursor is already on the link; a prediction fires while it is still travelling.
- **Intent, not the whole viewport.** Prefetching every visible link spends bandwidth and server time on pages nobody opens.
- **Turn the framework prefetch off only where the hook replaces it.** `prefetch={false}` switches off both viewport and hover prefetching, so on its own it removes prefetching entirely ([Next.js Link](https://nextjs.org/docs/app/api-reference/components/link), checked 3 October 2026).
- **Widen the target.** `hitSlop` grows the invisible prediction area, so the path only has to point near the link.
- **Touch has no cursor.** ForesightJS falls back to its `touchDeviceStrategy` setting, `"viewport"` by default.
- **Keyboard counts.** Tab prediction (on by default, `tabOffset: 3`) prefetches when focus is a few stops away.
- **Use it where latency shows**: data-heavy dashboards, slow APIs, product pages. A static site or an app with its data already loaded gains nothing.

## Next.js wiring

The pattern from the ForesightJS Next.js guide, with `@foresightjs/react` 1.0.0 ([ForesightJS Next.js](https://foresightjs.com/docs/react/nextjs/); [npm](https://www.npmjs.com/package/@foresightjs/react), both checked 3 October 2026):

```tsx
"use client";
import type { ReactNode } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForesight } from "@foresightjs/react";

export function ForesightLink({ href, name, children }: { href: string; name: string; children: ReactNode }) {
  const router = useRouter();
  const { elementRef } = useForesight({
    callback: () => router.prefetch(href),
    hitSlop: 20,
    name,
  });

  // Next's own prefetch is off only because the callback above prefetches instead.
  return (
    <Link href={href} ref={elementRef} prefetch={false}>
      {children}
    </Link>
  );
}
```

Next.js prefetches only in production builds (same Link page), so test the behaviour there, not in `next dev`.
