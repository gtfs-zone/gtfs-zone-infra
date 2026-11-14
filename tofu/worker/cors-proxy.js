// CORS proxy: https://cors.gtfs.zone/<target URL>
// Fetches the target and returns it with CORS headers for allowlisted origins.
// IP-literal targets are fetched as <ip>.sslip.io, since Workers cannot fetch a
// bare IP (error 1003); sslip.io resolves that name back to the same address.

const STRIP = ["cookie", "authorization", "origin", "referer"];

function text(status, body, cors = {}) {
  return new Response(body, { status, headers: { "content-type": "text/plain", ...cors } });
}

// Parses an IPv4 or IPv6 literal into a list of numbers, or null.
function parseIp(host) {
  const v4 = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (v4) {
    const p = v4.slice(1).map(Number);
    return p.every((n) => n <= 255) ? { v: 4, p } : null;
  }
  if (host.startsWith("[") && host.endsWith("]")) {
    const h = host.slice(1, -1);
    const [head, tail = ""] = h.split("::");
    const a = head ? head.split(":") : [];
    const b = h.includes("::") && tail ? tail.split(":") : [];
    if (!h.includes("::") && a.length !== 8) return null;
    const groups = [...a, ...Array(8 - a.length - b.length).fill("0"), ...b];
    const p = groups.map((g) => parseInt(g, 16));
    return p.length === 8 && p.every((n) => n >= 0 && n <= 0xffff) ? { v: 6, p } : null;
  }
  return null;
}

// True for loopback, private, link-local, unique-local, multicast, broadcast
// and unspecified addresses.
function isPrivateIp({ v, p }) {
  if (v === 4) {
    const [a, b] = p;
    return a === 0 || a === 10 || a === 127 || (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) ||
      (a === 100 && b >= 64 && b <= 127) || a >= 224;
  }
  const [g0] = p;
  const unspecOrLoop = p.slice(0, 7).every((n) => n === 0) && p[7] <= 1;
  const mapped = p.slice(0, 5).every((n) => n === 0) && p[5] === 0xffff;
  if (mapped) return isPrivateIp({ v: 4, p: [p[6] >> 8, p[6] & 255, p[7] >> 8, p[7] & 255] });
  return unspecOrLoop || (g0 & 0xfe00) === 0xfc00 || (g0 & 0xffc0) === 0xfe80 || (g0 & 0xff00) === 0xff00;
}

// sslip.io name for an IP literal: 1.2.3.4 -> 1.2.3.4.sslip.io,
// [2001:db8::1] -> 2001-db8--1.sslip.io.
function sslipHost(host, ip) {
  if (ip.v === 4) return `${host}.sslip.io`;
  return `${host.slice(1, -1).replace(/:/g, "-")}.sslip.io`;
}

function corsHeaders(origin) {
  return { "access-control-allow-origin": origin, vary: "Origin" };
}

export default {
  async fetch(req, env) {
    const allowed = env.ALLOWED_ORIGINS.split(",").map((s) => s.trim()).filter(Boolean);
    const url = new URL(req.url);

    // Origin, or the Referer's origin when the browser omitted Origin.
    let origin = req.headers.get("origin");
    if (!origin && req.headers.get("referer")) {
      try {
        const r = new URL(req.headers.get("referer")).origin;
        if (allowed.includes(r)) origin = r;
      } catch {}
    }
    if (!origin) return text(400, "Missing required request header: Origin");
    if (!allowed.includes(origin)) return text(403, `Origin ${origin} is not allowed`);
    const cors = corsHeaders(origin);

    if (req.method === "OPTIONS") {
      const h = { ...cors, "access-control-max-age": "86400" };
      const m = req.headers.get("access-control-request-method");
      const rh = req.headers.get("access-control-request-headers");
      if (m) h["access-control-allow-methods"] = m;
      if (rh) h["access-control-allow-headers"] = rh;
      return new Response(null, { status: 200, headers: h });
    }

    // Target is the path plus query; restore "//" that browsers and proxies collapse.
    const raw = (url.pathname.slice(1) + url.search).replace(/^(https?:)\/(?!\/)/, "$1//");
    let target;
    try {
      target = new URL(raw);
    } catch {
      return text(400, "Bad Request: invalid or missing target URL", cors);
    }
    if (target.protocol !== "http:" && target.protocol !== "https:") {
      return text(400, "Bad Request: invalid or missing target URL", cors);
    }

    const host = target.hostname;
    if (host === "localhost" || host.endsWith(".local") || host.endsWith(".internal")) {
      return text(403, "Forbidden: private network targets not allowed", cors);
    }
    const ip = parseIp(host);
    if (ip && isPrivateIp(ip)) {
      return text(403, "Forbidden: private network targets not allowed", cors);
    }
    const requestUrl = target.toString();
    if (ip) target.hostname = sslipHost(host, ip);

    const headers = new Headers(req.headers);
    for (const h of STRIP) headers.delete(h);
    let upstream;
    try {
      upstream = await fetch(target.toString(), {
        method: req.method,
        headers,
        body: req.method === "GET" || req.method === "HEAD" ? undefined : req.body,
        redirect: "follow",
      });
    } catch (e) {
      return text(502, `Bad Gateway: ${e.message}`, cors);
    }

    const out = new Headers(upstream.headers);
    for (const h of ["set-cookie", "set-cookie2"]) out.delete(h);
    out.set("x-request-url", requestUrl);
    const final = new URL(upstream.url || target.toString());
    if (ip && final.hostname === target.hostname) final.hostname = host;
    out.set("x-final-url", final.toString());
    for (const [k, v] of Object.entries(cors)) out.set(k, v);
    out.set("access-control-expose-headers", [...out.keys()].join(","));
    return new Response(upstream.body, { status: upstream.status, statusText: upstream.statusText, headers: out });
  },
};
