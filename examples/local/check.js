// Run with Node in the dockge container, which shares the host's network and
// has socket.io-client: `podman exec -i dockge node - setup < check.js`.
// "setup" creates the admin, the way the setup page does, and deploys a stack
// with one nginx service on a bridge network, published on 127.0.0.1:18080.
// "verify" logs in again and finds the stack running with nginx answering,
// which shows the account, the stack and its container outlived the change.
const { io } = require("/app/node_modules/socket.io-client");

const url = "http://127.0.0.1:5001";
const user = "admin";
const pass = "ci-check-Password-1";
const what = process.argv[2];
const RUNNING = 3;
const compose = `services:
  web:
    image: docker.io/library/nginx:1.29.3-alpine@sha256:b3c656d55d7ad751196f21b7fd2e8d4da9cb430e32f646adcf92441b72f82b14
    ports:
      - 127.0.0.1:18080:80
    restart: unless-stopped
`;

const fail = (m) => {
  console.error("FAIL: " + m);
  process.exit(1);
};
setTimeout(() => fail("timed out"), 300000);

const socket = io(url, { transports: ["websocket"], reconnection: false });
const call = (event, ...args) => new Promise((resolve) => socket.emit(event, ...args, resolve));
// Stack commands go through the "agent" event; "" is this Dockge itself.
const agent = (event, ...args) => call("agent", "", event, ...args);
let stacks = {};
socket.on("agent", (event, data) => {
  if (event === "stackList" && data.ok) stacks = data.stackList;
});
socket.on("connect_error", (e) => fail("connect: " + e.message));

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

socket.on("connect", async () => {
  if (what === "setup") {
    const s = await call("setup", user, pass);
    if (!s.ok) fail("setup: " + s.msg);
  }
  const bad = await call("login", { username: user, password: "wrong-password", token: "" });
  if (bad.ok) fail("a wrong password logged in");
  const l = await call("login", { username: user, password: pass, token: "" });
  if (!l.ok) fail("login: " + l.msg);
  if (what === "setup") {
    const d = await agent("deployStack", "hello", compose, "", true);
    if (!d.ok) fail("deploy: " + d.msg);
  }
  for (;;) {
    if (stacks.hello?.status === RUNNING) {
      const r = await fetch("http://127.0.0.1:18080").catch(() => null);
      if (r?.ok && (await r.text()).includes("Welcome to nginx")) break;
    }
    await sleep(2000);
    agent("requestStackList");
  }
  console.log(what + ": ok");
  process.exit(0);
});
