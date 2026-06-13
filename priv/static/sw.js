// 方言ポーチ — Service Worker
// 戦略: network-first（常にネット優先、失敗時のみキャッシュへフォールバック）。
// dev/prod どちらでも stale な資産を出さず安全。オフライン時のみキャッシュが効く。
// バージョンを上げると新 SW が install され、クライアント側で更新トーストが出る。

const CACHE_VERSION = "v1";
const CACHE_NAME = `dialect-pouch-${CACHE_VERSION}`;

// オフライン時に最低限返す簡易フォールバック（ナビゲーションがキャッシュにも無い場合）
const OFFLINE_HTML = `<!doctype html><html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>オフライン · 方言ポーチ</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#FBF7F1;
color:#2B231C;font-family:"Hiragino Kaku Gothic ProN","Yu Gothic",sans-serif;text-align:center;padding:24px}
h1{color:#B6542E;font-size:1.25rem;margin:0 0 .5rem}p{color:#8C7E6C;margin:0}</style></head>
<body><div><h1>オフラインです</h1><p>接続が戻ったら再度お試しください。</p></div></body></html>`;

self.addEventListener("install", (event) => {
  // 新バージョンを即座に待機状態へ（更新フローはクライアントの SKIP_WAITING が制御）
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      // 旧バージョンのキャッシュを削除
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter((k) => k.startsWith("dialect-pouch-") && k !== CACHE_NAME)
          .map((k) => caches.delete(k))
      );
      await self.clients.claim();
    })()
  );
});

// クライアントからの更新指示で待機中 SW を即時有効化
self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "SKIP_WAITING") {
    self.skipWaiting();
  }
});

self.addEventListener("fetch", (event) => {
  const req = event.request;

  // GET 以外は素通し（フォーム POST / LiveView longpoll など）
  if (req.method !== "GET") return;

  const url = new URL(req.url);

  // 同一オリジンのみ対象（外部フォント等はブラウザ任せ）
  if (url.origin !== self.location.origin) return;

  // LiveView の通信は触らない
  if (url.pathname.startsWith("/live")) return;

  const isNavigation =
    req.mode === "navigate" ||
    (req.headers.get("accept") || "").includes("text/html");

  event.respondWith(
    (async () => {
      try {
        const fresh = await fetch(req);
        // 成功レスポンスをオフライン用にキャッシュ（basic = 同一オリジン）
        if (fresh && fresh.ok && fresh.type === "basic") {
          const cache = await caches.open(CACHE_NAME);
          cache.put(req, fresh.clone());
        }
        return fresh;
      } catch (err) {
        // オフライン: キャッシュ → 無ければフォールバック
        const cached = await caches.match(req);
        if (cached) return cached;
        if (isNavigation) {
          return new Response(OFFLINE_HTML, {
            headers: { "Content-Type": "text/html; charset=utf-8" },
          });
        }
        throw err;
      }
    })()
  );
});
