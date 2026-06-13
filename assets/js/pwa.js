// 方言ポーチ — PWA クライアント配線
//   1. Service Worker 登録
//   2. アプリ更新の検知 →「更新」トースト → リロード
//   3. インストール案内（Android/PC は beforeinstallprompt、iOS は手動手順）
// UI は daisyUI クラスで描画し、暖色テーマに馴染ませる。

const INSTALL_DISMISS_KEY = "pwa:install-dismissed";

// ── 表示抑制の判定 ─────────────────────────────────────────
const isStandalone = () =>
  window.matchMedia("(display-mode: standalone)").matches ||
  window.navigator.standalone === true;

const isIOS = () =>
  /iphone|ipad|ipod/i.test(navigator.userAgent) ||
  (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);

const isIOSSafari = () =>
  isIOS() && /safari/i.test(navigator.userAgent) &&
  !/crios|fxios|edgios/i.test(navigator.userAgent);

// ── トースト用コンテナ ─────────────────────────────────────
function toastHost() {
  let host = document.getElementById("pwa-toasts");
  if (!host) {
    host = document.createElement("div");
    host.id = "pwa-toasts";
    host.className = "toast toast-center toast-bottom z-50";
    host.style.cssText = "position:fixed;left:50%;bottom:1rem;transform:translateX(-50%);z-index:60;";
    document.body.appendChild(host);
  }
  return host;
}

function dismissBox(id) {
  const el = document.getElementById(id);
  if (el) el.remove();
}

// ── 更新トースト ───────────────────────────────────────────
function showUpdateToast(worker) {
  dismissBox("pwa-update");
  const box = document.createElement("div");
  box.id = "pwa-update";
  box.className = "alert shadow-lg";
  box.style.cssText =
    "background:#FBF2E8;border:1px solid #E7DCCB;color:#2B231C;max-width:92vw;align-items:center;gap:.75rem;";
  box.innerHTML = `
    <span style="font-size:.95rem;">新しいバージョンがあります</span>
    <span style="display:flex;gap:.4rem;">
      <button type="button" data-act="reload" class="btn btn-sm"
        style="background:#B6542E;border-color:#B6542E;color:#fff;">更新</button>
      <button type="button" data-act="later" class="btn btn-sm btn-ghost"
        style="color:#8C7E6C;">後で</button>
    </span>`;
  box.querySelector('[data-act="reload"]').addEventListener("click", () => {
    if (worker) worker.postMessage({ type: "SKIP_WAITING" });
  });
  box.querySelector('[data-act="later"]').addEventListener("click", () =>
    dismissBox("pwa-update")
  );
  toastHost().appendChild(box);
}

// ── インストール案内（Android/PC）─────────────────────────
function showInstallBanner(deferredPrompt) {
  if (localStorage.getItem(INSTALL_DISMISS_KEY) === "1") return;
  dismissBox("pwa-install");
  const box = document.createElement("div");
  box.id = "pwa-install";
  box.className = "alert shadow-lg";
  box.style.cssText =
    "background:#FBF2E8;border:1px solid #E7DCCB;color:#2B231C;max-width:92vw;align-items:center;gap:.75rem;";
  box.innerHTML = `
    <span style="font-size:.95rem;">方言ポーチをホーム画面に追加</span>
    <span style="display:flex;gap:.4rem;">
      <button type="button" data-act="install" class="btn btn-sm"
        style="background:#B6542E;border-color:#B6542E;color:#fff;">インストール</button>
      <button type="button" data-act="close" class="btn btn-sm btn-ghost"
        style="color:#8C7E6C;">閉じる</button>
    </span>`;
  box.querySelector('[data-act="install"]').addEventListener("click", async () => {
    dismissBox("pwa-install");
    deferredPrompt.prompt();
    try { await deferredPrompt.userChoice; } catch (_e) {}
  });
  box.querySelector('[data-act="close"]').addEventListener("click", () => {
    localStorage.setItem(INSTALL_DISMISS_KEY, "1");
    dismissBox("pwa-install");
  });
  toastHost().appendChild(box);
}

// ── インストール案内（iOS Safari、手動手順）────────────────
function showIOSInstallHint() {
  if (localStorage.getItem(INSTALL_DISMISS_KEY) === "1") return;
  dismissBox("pwa-install");
  const box = document.createElement("div");
  box.id = "pwa-install";
  box.className = "alert shadow-lg";
  box.style.cssText =
    "background:#FBF2E8;border:1px solid #E7DCCB;color:#2B231C;max-width:92vw;align-items:flex-start;gap:.5rem;flex-direction:column;";
  box.innerHTML = `
    <div style="display:flex;width:100%;justify-content:space-between;align-items:center;gap:.5rem;">
      <span style="font-size:.95rem;">ホーム画面に追加できます</span>
      <button type="button" data-act="close" class="btn btn-xs btn-ghost"
        style="color:#8C7E6C;">閉じる</button>
    </div>
    <span style="font-size:.82rem;color:#8C7E6C;">
      共有ボタン <span aria-hidden="true">⬆️</span> →「ホーム画面に追加」を選択してください。
    </span>`;
  box.querySelector('[data-act="close"]').addEventListener("click", () => {
    localStorage.setItem(INSTALL_DISMISS_KEY, "1");
    dismissBox("pwa-install");
  });
  toastHost().appendChild(box);
}

// ── 起動 ───────────────────────────────────────────────────
export function initPWA() {
  if (!("serviceWorker" in navigator)) return;

  // インストール案内（Android/PC）
  let deferredPrompt = null;
  window.addEventListener("beforeinstallprompt", (e) => {
    e.preventDefault();
    deferredPrompt = e;
    if (!isStandalone()) showInstallBanner(deferredPrompt);
  });
  window.addEventListener("appinstalled", () => {
    deferredPrompt = null;
    dismissBox("pwa-install");
    localStorage.setItem(INSTALL_DISMISS_KEY, "1");
  });

  // iOS Safari は beforeinstallprompt が無いので手動手順を案内
  if (isIOSSafari() && !isStandalone()) {
    window.addEventListener("load", () => setTimeout(showIOSInstallHint, 1500));
  }

  // コントローラ切替 → 一度だけリロード（更新適用）
  let refreshing = false;
  navigator.serviceWorker.addEventListener("controllerchange", () => {
    if (refreshing) return;
    refreshing = true;
    window.location.reload();
  });

  window.addEventListener("load", async () => {
    try {
      const reg = await navigator.serviceWorker.register("/sw.js");

      // 既に待機中の新バージョンがあれば即案内
      if (reg.waiting && navigator.serviceWorker.controller) {
        showUpdateToast(reg.waiting);
      }

      // 新バージョンの install を検知
      reg.addEventListener("updatefound", () => {
        const nw = reg.installing;
        if (!nw) return;
        nw.addEventListener("statechange", () => {
          if (nw.state === "installed" && navigator.serviceWorker.controller) {
            showUpdateToast(nw);
          }
        });
      });
    } catch (_e) {
      // 登録失敗は致命的でないため握りつぶす
    }
  });
}
