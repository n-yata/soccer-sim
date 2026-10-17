// drawio-mcp-server を、空いているポートで起動するためのラッパー（.mcp.json から呼ぶ）。
//
// drawio-mcp-server は既定でポート 3333（WebSocket）と 3000（エディタ）を固定で使う。
// Claude Code のセッションを複数開くと（別プロジェクトを含む）、後から起動したセッションが
// 「Port 3333 is already in use」で毎回接続に失敗する。起動のたびに空きポートを選んで渡し、
// セッション同士が衝突しないようにする。
//
// エディタの URL は起動のたびに変わるため、OS の一時ディレクトリの drawio-mcp/ に
// 「<起動ディレクトリ名>-<pid>.json」として書き出す（終了時に消す。強制終了で残ったものは次の起動時に消す）。
// 一覧と読み方は docs/specs/1_requirements/repository-structure.md「drawio MCP の運用」。

import { spawn } from "node:child_process";
import { lstatSync, mkdirSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";

// npx が毎回最新版を取りに行かないよう、版を固定する（更新するときはここを変える）
const SERVER_PACKAGE = "drawio-mcp-server@2.3.0";
// 同じ端末の中からだけ接続できるようにする（既定は全アドレスで待ち受ける）
const HOST = "127.0.0.1";

/** OS に空きポートを2つ割り当てさせ、番号だけを受け取って閉じる。 */
async function reservePorts() {
  // 同時に2つ開いてから閉じることで、2つが同じ番号にならないようにする
  const servers = [createServer(), createServer()];
  const ports = await Promise.all(
    servers.map(
      (server) =>
        new Promise((resolve, reject) => {
          server.once("error", reject);
          server.listen(0, HOST, () => resolve(server.address().port));
        }),
    ),
  );
  await Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve))));
  return ports;
}

const [extensionPort, httpPort] = await reservePorts();

const infoDir = join(tmpdir(), "drawio-mcp");
const infoFile = join(infoDir, `${basename(process.cwd())}-${process.pid}.json`);
let wroteInfo = false;

/** 共有の一時ディレクトリでも、他人が用意したディレクトリやリンクに書き込まないことを確かめる。 */
function ensurePrivateDir(dir) {
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const stat = lstatSync(dir);
  const ownedByMe = typeof process.getuid !== "function" || stat.uid === process.getuid();
  if (!stat.isDirectory() || stat.isSymbolicLink() || !ownedByMe) {
    throw new Error(`unsafe directory: ${dir}`);
  }
}

function isAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error.code === "EPERM"; // 存在するが権限がない
  }
}

/**
 * 強制終了で消えずに残った、もう動いていないプロセスの URL ファイルを消す。
 * 自分の pid のファイルも、書き出す前の時点では pid が再利用された古いものなので消す。
 */
function removeStaleInfo(dir) {
  for (const name of readdirSync(dir)) {
    const match = /-(\d+)\.json$/.exec(name);
    if (!match) continue;
    const pid = Number(match[1]);
    if (pid === process.pid || !isAlive(pid)) {
      try {
        rmSync(join(dir, name), { force: true });
      } catch {
        // 掃除はついでの処理なので、失敗しても自分の書き出しは続ける
      }
    }
  }
}

try {
  ensurePrivateDir(infoDir);
  removeStaleInfo(infoDir);
  const info = {
    cwd: process.cwd(),
    pid: process.pid,
    editorUrl: `http://${HOST}:${httpPort}/`,
    extensionPort,
    startedAt: new Date().toISOString(),
  };
  // wx: 既存のファイルやリンクをたどって上書きしない
  writeFileSync(infoFile, JSON.stringify(info, null, 2), { flag: "wx", mode: 0o600 });
  wroteInfo = true;
} catch (error) {
  // URL の書き出しに失敗しても、サーバーの起動は続ける（エディタの URL が分からなくなるだけ）。
  // stdout は MCP の通信路なので、理由は stderr に出す
  process.stderr.write(`drawio-mcp: could not write editor info to ${infoFile}: ${error.message}
`);
}

const removeInfo = () => {
  if (wroteInfo) rmSync(infoFile, { force: true });
};

// stdin/stdout は MCP の通信路なので、そのまま子プロセスに引き継ぐ。
// Windows の npx は npx.cmd のため、shell 経由でないと起動できない（引数は固定値と数値だけ）。
const child = spawn(
  "npx",
  [
    "-y",
    SERVER_PACKAGE,
    "--editor",
    "--host",
    HOST,
    "--extension-port",
    String(extensionPort),
    "--http-port",
    String(httpPort),
  ],
  { stdio: "inherit", shell: process.platform === "win32" },
);

child.on("exit", (code, signal) => {
  removeInfo();
  process.exit(code ?? (signal ? 1 : 0));
});
child.on("error", (error) => {
  removeInfo();
  process.stderr.write(`drawio-mcp: failed to start ${SERVER_PACKAGE}: ${error.message}\n`);
  process.exit(1);
});
for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(sig, () => {
    child.kill(sig);
  });
}
