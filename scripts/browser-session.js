#!/usr/bin/env node
// Open a logged-in session in a dedicated Chrome profile, for page-scan.sh.
//
// Usage: node browser-session.js <chrome> <profile-dir> <url> token <storage-key> [--keep]
//        node browser-session.js <chrome> <profile-dir> <url> form [--keep]
//        node browser-session.js <chrome> <profile-dir> <url> clone <source-port> [--keep]
//
// token: stores SISKA_SCAN_TOKEN in the page's localStorage under <storage-key>
//        (the key the front end reads, found in its code), like the app does after login.
// form:  loads <url> (the login page), fills SISKA_SCAN_USER / SISKA_SCAN_PASSWORD
//        into the visible login form, submits it and waits until the form is gone.
// clone: copies the session of the Chrome listening on <source-port> (the --login window):
//        all its cookies, HttpOnly included, and the localStorage of <url>'s origin. The
//        measure then runs headless, where pages paint even if the window is in the background.
// --keep: leave Chrome running after the login and print "PORT PID" on the last line,
// so Lighthouse can measure in the same browser (session cookies die with Chrome).
// Without --keep, Chrome is closed and only persistent storage (localStorage,
// cookies with an expiry) stays in <profile-dir>.
// Secrets are read from the environment only, sent to the page as JSON arguments,
// never printed. Chrome runs headless.
// Needs Node 22+ (global WebSocket and fetch). Exit code: 0 logged in, 1 failed, 2 usage error.
"use strict";
const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");

const args = process.argv.slice(2);
const keep = args.includes("--keep");
const [chrome, profile, url, mode, storageKey] = args.filter((a) => a !== "--keep");
const sourcePort = mode === "clone" ? storageKey : null;
const fail = (msg, code = 1) => { console.error(`ERROR: ${msg}`); process.exit(code); };
if (!chrome || !profile || !/^https?:\/\//.test(url || "") || !["token", "form", "clone"].includes(mode)) fail("usage: browser-session.js <chrome> <profile> <url> token <key> | form | clone <port>", 2);
if (mode === "clone" && !/^\d+$/.test(sourcePort || "")) fail("clone mode needs the source Chrome's debugging port", 2);
if (typeof WebSocket !== "function") fail("Node 22 or newer is required (global WebSocket)", 2);
if (mode === "token" && (!storageKey || !process.env.SISKA_SCAN_TOKEN)) fail("token mode needs SISKA_SCAN_TOKEN and the localStorage key", 2);
if (mode === "form" && (!process.env.SISKA_SCAN_USER || !process.env.SISKA_SCAN_PASSWORD)) fail("form mode needs SISKA_SCAN_USER and SISKA_SCAN_PASSWORD", 2);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Minimal DevTools protocol client over one WebSocket.
async function cdp(wsUrl) {
  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error("cannot connect to Chrome")); });
  let id = 0; const pending = new Map();
  ws.onmessage = (m) => { const msg = JSON.parse(m.data); if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); } };
  const send = (method, params = {}) => new Promise((res) => { const n = ++id; pending.set(n, res); ws.send(JSON.stringify({ id: n, method, params })); });
  return { ws, send };
}

// Session of the source Chrome: every cookie, and the localStorage of the origin (read in one of its tabs).
async function readSource(port, origin) {
  const version = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json();
  const browser = await cdp(version.webSocketDebuggerUrl);
  const cookies = ((await browser.send("Storage.getCookies")).result || {}).cookies || [];
  browser.ws.close();
  let storage = [];
  const tab = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find((t) => t.type === "page" && t.url.startsWith(origin));
  if (tab) {
    const page = await cdp(tab.webSocketDebuggerUrl);
    const r = await page.send("Runtime.evaluate", { expression: "JSON.stringify(Object.entries(localStorage))", returnByValue: true });
    storage = JSON.parse((r.result && r.result.result && r.result.result.value) || "[]");
    page.ws.close();
  }
  return { cookies, storage, tab: Boolean(tab) };
}

async function main() {
  fs.mkdirSync(profile, { recursive: true, mode: 0o700 });
  const portFile = path.join(profile, "DevToolsActivePort");
  fs.rmSync(portFile, { force: true });
  // Own process group, so the caller can stop Chrome and its children with one kill.
  const proc = spawn(chrome, ["--headless=new", `--user-data-dir=${profile}`, "--remote-debugging-port=0", "--no-first-run", "--no-default-browser-check", "about:blank"], { stdio: "ignore", detached: true });
  let done = false;
  process.on("exit", () => { if (!done) { try { process.kill(-proc.pid); } catch (_) {} } });

  let port;
  for (let i = 0; i < 100 && !port; i++) { await sleep(100); try { port = fs.readFileSync(portFile, "utf8").split("\n")[0].trim(); } catch (_) {} }
  if (!port) throw new Error("Chrome did not start (is another Chrome using this profile?)");
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const page = targets.find((t) => t.type === "page");
  if (!page) throw new Error("no page target in Chrome");

  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error("cannot connect to Chrome")); });
  let id = 0; const pending = new Map();
  ws.onmessage = (m) => { const msg = JSON.parse(m.data); if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); } };
  const send = (method, params = {}) => new Promise((res) => { const n = ++id; pending.set(n, res); ws.send(JSON.stringify({ id: n, method, params })); });
  // Evaluate fn(...args) in the page; args are JSON values, so secrets are never spliced into code.
  const call = async (fn, ...args) => {
    const r = await send("Runtime.evaluate", { expression: `(${fn})(...${JSON.stringify(args)})`, awaitPromise: true, returnByValue: true });
    if (r.result && r.result.exceptionDetails) throw new Error("page script failed");
    return r.result && r.result.result ? r.result.result.value : undefined;
  };
  const waitFor = async (fn, ms) => { for (let t = 0; t < ms; t += 250) { if (await call(fn).catch(() => false)) return true; await sleep(250); } return false; };

  let source;
  if (mode === "clone") {
    source = await readSource(sourcePort, new URL(url).origin);
    if (!source.cookies.length && !source.storage.length) throw new Error("the session window has no cookies nor storage for this site: log in there first");
    const allowed = ["name", "value", "domain", "path", "secure", "httpOnly", "sameSite", "priority", "sourceScheme", "sourcePort", "partitionKey"];
    const params = source.cookies.map((c) => { const p = {}; for (const k of allowed) if (c[k] !== undefined) p[k] = c[k]; if (!c.session && c.expires > 0) p.expires = c.expires; return p; });
    await send("Network.enable");
    const set = await send("Network.setCookies", { cookies: params });
    if (set.error) throw new Error(`could not copy the cookies (${set.error.message})`);
  }

  await send("Page.enable");
  await send("Page.navigate", { url });
  await waitFor(() => document.readyState === "complete", 20000);

  const hasPassword = () => [...document.querySelectorAll("input[type=password]")].some((e) => e.offsetParent !== null);
  if (mode === "clone") {
    if (source.storage.length) await call((entries) => { for (const [k, v] of entries) localStorage.setItem(k, v); return true; }, source.storage);
    console.log(`OK:    session copied from the open window (${source.cookies.length} cookies, ${source.storage.length} storage keys${source.tab ? "" : "; no tab of this site open there, localStorage not copied"})`);
  } else if (mode === "token") {
    await call((key, value) => { localStorage.setItem(key, value); return true; }, storageKey, process.env.SISKA_SCAN_TOKEN);
    console.log(`OK:    token stored in localStorage["${storageKey}"] for ${new URL(url).origin}`);
  } else {
    if (!(await waitFor(hasPassword, 15000))) throw new Error("no visible password field on this page – give the login page URL, or use the manual --login");
    const result = await call((user, pass) => {
      const vis = (e) => e && e.offsetParent !== null;
      const pwd = [...document.querySelectorAll("input[type=password]")].find(vis);
      const scope = pwd.form || document;
      const login = [...scope.querySelectorAll("input[type=email],input[autocomplete=username],input[name*=user i],input[name*=email i],input[name*=login i],input[id*=user i],input[id*=email i],input[type=text]")].find(vis);
      if (!login) return "no-user-field";
      // Native setter + input event, so controlled inputs (React, Vue) see the value.
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
      for (const [el, v] of [[login, user], [pwd, pass]]) { setter.call(el, v); el.dispatchEvent(new Event("input", { bubbles: true })); el.dispatchEvent(new Event("change", { bubbles: true })); }
      const btn = (pwd.form && pwd.form.querySelector("button[type=submit],input[type=submit],button:not([type])")) ||
        [...document.querySelectorAll("button")].find((b) => vis(b) && /log ?in|sign ?in|connexion|se connecter|connecter|valider|continuer/i.test(b.textContent));
      if (pwd.form && pwd.form.requestSubmit) pwd.form.requestSubmit(btn && btn.form === pwd.form ? btn : undefined);
      else if (btn) btn.click();
      else return "no-submit-button";
      return "submitted";
    }, process.env.SISKA_SCAN_USER, process.env.SISKA_SCAN_PASSWORD);
    if (result !== "submitted") throw new Error(`login form not understood (${result}) – use the manual --login`);
    const gone = await waitFor(() => ![...document.querySelectorAll("input[type=password]")].some((e) => e.offsetParent !== null), 20000);
    if (!gone) throw new Error("still on the login form after submit: wrong credentials, captcha or 2FA – use the manual --login");
    console.log(`OK:    logged in on ${new URL(url).origin}`);
  }
  // Let the app persist its session.
  await sleep(1500);
  if (keep) {
    ws.close(); done = true; proc.unref();
    console.log(`${port} ${proc.pid}`);
    return;
  }
  // Close Chrome cleanly so the profile is written.
  await send("Browser.close").catch(() => {});
  ws.close();
  for (let i = 0; i < 50 && proc.exitCode === null; i++) await sleep(100);
}

main().then(() => process.exit(0), (e) => fail(e.message));
