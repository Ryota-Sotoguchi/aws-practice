// 訪問者カウンター
// - このタブで初めて開いたとき：POST でカウントを +1
// - 再読み込みしたとき：GET で今の値を表示するだけ
(async () => {
  const el = document.getElementById("visitor-count");
  const api = window.APP_CONFIG && window.APP_CONFIG.counterApi;
  if (!el) return;

  if (!api) {
    el.textContent = "—";
    console.error("visitor counter: config.js が読み込めていません");
    return;
  }

  let alreadyCounted = false;
  try {
    alreadyCounted = sessionStorage.getItem("visitor-counted") === "1";
  } catch (e) {
    // プライベートモードなどで sessionStorage が使えない場合は毎回数える
  }

  try {
    const res = await fetch(api, { method: alreadyCounted ? "GET" : "POST" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    const data = await res.json();
    el.textContent = Number(data.count).toLocaleString("ja-JP");

    if (!alreadyCounted) {
      try {
        sessionStorage.setItem("visitor-counted", "1");
      } catch (e) {
        /* 何もしない */
      }
    }
  } catch (err) {
    el.textContent = "—";
    console.error("visitor counter:", err);
  }
})();
