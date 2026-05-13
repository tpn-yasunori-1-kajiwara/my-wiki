// Wiki に登録 — Chrome 拡張 (Manifest V3) のバックグラウンド service worker。
//
// 右クリックメニュー 3 種類:
//   - Wiki に登録 (このページ)
//   - Wiki に登録 (選択範囲)
//   - Wiki に登録 (このリンク先)
//
// いずれも localhost:7777/register に POST する。
// デーモン (scripts/wiki-daemon.ps1) が動いていないと失敗する。

const ENDPOINT = "http://localhost:7777/register";

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: "wiki-page",
      title: "Wiki に登録 (このページ)",
      contexts: ["page"],
    });
    chrome.contextMenus.create({
      id: "wiki-selection",
      title: "Wiki に登録 (選択範囲)",
      contexts: ["selection"],
    });
    chrome.contextMenus.create({
      id: "wiki-link",
      title: "Wiki に登録 (このリンク先)",
      contexts: ["link"],
    });
  });
});

async function postRegister(payload) {
  try {
    const res = await fetch(ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!res.ok) throw new Error("HTTP " + res.status);
    const data = await res.json();
    notify("登録しました", data.file || "raw/ に書き込み済み");
    flashBadge("OK", "#0a7d2c");
  } catch (e) {
    notify("登録失敗", e.message + " — デーモンが起動しているか確認してください");
    flashBadge("ERR", "#a52121");
  }
}

function notify(title, message) {
  try {
    chrome.notifications.create({
      type: "basic",
      iconUrl: "icon.png",
      title: title,
      message: message,
    });
  } catch (e) {
    console.log("[wiki]", title, message);
  }
}

function flashBadge(text, color) {
  try {
    chrome.action.setBadgeText({ text: text });
    chrome.action.setBadgeBackgroundColor({ color: color });
    setTimeout(() => chrome.action.setBadgeText({ text: "" }), 3000);
  } catch (e) {}
}

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === "wiki-page") {
    postRegister({
      source_type: "browser-page",
      url: tab.url,
      title: tab.title,
      content: "",
    });
  } else if (info.menuItemId === "wiki-selection") {
    postRegister({
      source_type: "browser-selection",
      url: tab.url,
      title: tab.title,
      content: info.selectionText || "",
    });
  } else if (info.menuItemId === "wiki-link") {
    postRegister({
      source_type: "browser-link",
      url: info.linkUrl,
      title: info.linkUrl,
      content: "",
    });
  }
});

// ツールバーアイコンをクリックすると /health を叩く (デバッグ用)
chrome.action.onClicked.addListener(async () => {
  try {
    const res = await fetch("http://localhost:7777/health");
    const data = await res.json();
    notify("デーモン応答", `status=${data.status} port=${data.port}`);
  } catch (e) {
    notify("デーモン不通", "wiki-daemon.ps1 が起動していない可能性");
  }
});
