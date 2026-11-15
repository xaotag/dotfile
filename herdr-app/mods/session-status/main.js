// session-status — 右侧 Files 面板下方的状态块
//
// 结构: 分组标题 + 树形列表 (竖线连续)
//   mcp 5
//   ├─ github        ← 绿: 已注册且可用
//   │  ├─ ...
//   └─ broken-demo   ← 红: 注册但不可用
//
// 颜色: ansi2 绿 = 可用 / blocked 红 = 不可用 / dim 暗 = 无内容
//
// 性能: MCP 可用性一次 PowerShell 批量检测, 避免 N 次进程启动

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { spaces, theme, exec, readTextFile, appHome, run } from "herdr";

function piDir() {
  const h = appHome().replace(/[\\/]\.config[\\/]herdr-app\/?$/, "");
  return h.replace(/\\/g, "/") + "/.pi/agent";
}

const clip = (s, n) =>
  s.length <= n ? s : s.slice(0, Math.max(0, n - 1)) + "…";

const ROW_H = 19;
const INDENT = 14;

export default class SessionStatus extends View {
  init(_props, cx) {
    this.data = { mcp: [], skills: [], ext: [], git: null };
    this.busy = false;
    this.err = null;
    cx.timer.every(6000, (cx) => this.refresh(cx));
    this.refresh(cx);
  }

  refresh(cx) {
    if (this.busy) return;
    this.busy = true;
    const space = spaces().find((s) => s.active);
    const cwd = space?.folder ?? null;
    const on = space?.machine ?? null;
    const root = piDir().replace(/'/g, "''");
    const ps = (cmd) => exec("powershell", ["-NoProfile", "-Command", cmd], { on });

    cx.spawn(async (cx) => {
      const next = { ...this.data };
      try {
        // ── MCP 配置解析
        let entries = [];
        try {
          const raw = await readTextFile(piDir() + "/mcp.json", { on });
          if (raw) {
            const j = JSON.parse(raw);
            for (const [name, cfg] of Object.entries(j.mcpServers || {})) {
              if (!cfg) continue;
              if (cfg.enabled === false) {
                entries.push({ name, state: "dead" });
              } else if (cfg.url) {
                entries.push({ name, state: "ok" });
              } else if (!cfg.command) {
                entries.push({ name, state: "dead" });
              } else {
                entries.push({ name, state: "pending", cmd: String(cfg.command) });
              }
            }
          }
        } catch {
          entries = [];
        }

        // ── 批量检测 command 可用性 (一次 PowerShell)
        const pending = entries.filter((e) => e.state === "pending");
        if (pending.length) {
          const lines = pending.map((e) => {
            const c = e.cmd.replace(/'/g, "''");
            return (
              "$r+=@(if(Test-Path -LiteralPath '" +
              c +
              "'){'ok'}elseif(Get-Command '" +
              c +
              "' -EA SilentlyContinue){'ok'}else{'dead'})"
            );
          });
          const body = "$r=@();" + lines.join(";") + ";$r|ConvertTo-Json -Compress";
          let arr = [];
          try {
            const r = await ps(body);
            if (r.code === 0) {
              const v = JSON.parse((r.stdout || "").trim() || "[]");
              arr = Array.isArray(v) ? v : [v];
            }
          } catch {
            arr = [];
          }
          pending.forEach((e, i) => {
            e.state = arr[i] === "ok" ? "ok" : "dead";
            delete e.cmd;
          });
        }
        next.mcp = entries;

        // ── skills / extensions (一次 PowerShell)
        try {
          const body =
            "$r='" + root + "';" +
            "$s=@(Get-ChildItem -LiteralPath \"$r\\skills\" -Directory -EA SilentlyContinue|Select-Object -ExpandProperty Name);" +
            "$e=@();" +
            "if(Test-Path -LiteralPath \"$r\\extensions\"){" +
            "$e=@(Get-ChildItem -LiteralPath \"$r\\extensions\" -File -EA SilentlyContinue|Where-Object Name -match '\\.(ts|js)$'|ForEach-Object{$_.Name -replace '\\.(ts|js)$',''})" +
            "};" +
            "@($s)+@('---')+@($e)|ConvertTo-Json -Compress";
          const r = await ps(body);
          if (r.code === 0) {
            let arr = JSON.parse((r.stdout || "").trim() || "[]");
            if (!Array.isArray(arr)) arr = [arr];
            const i = arr.indexOf("---");
            const sk = i >= 0 ? arr.slice(0, i) : arr;
            const ex = i >= 0 ? arr.slice(i + 1) : [];
            next.skills = sk.map((n) => ({ name: n, state: "ok" }));
            next.ext = ex.map((n) => ({ name: n, state: "ok" }));
          }
        } catch {
          /* 保留旧值 */
        }

        // ── git
        if (cwd) {
          try {
            const h = await exec("git", ["rev-parse", "--abbrev-ref", "HEAD"], { cwd, on });
            if (h.code === 0) {
              const st = await exec("git", ["status", "--porcelain"], { cwd, on });
              next.git = {
                branch: h.stdout.trim(),
                dirty: st.code === 0 && st.stdout.trim().length > 0,
              };
            } else next.git = null;
          } catch {
            next.git = null;
          }
        } else next.git = null;

        // 只在数据真的变了才重绘, 避免无意义的全窗口刷新
        const changed = JSON.stringify(next) !== JSON.stringify(this.data);
        this.data = next;
        this.err = null;
        this.pendingNotify = changed;
      } catch (e) {
        this.err = String(e).slice(0, 60);
        this.pendingNotify = true;
      } finally {
        this.busy = false;
        if (this.pendingNotify) {
          this.pendingNotify = false;
          cx.notify();
        }
      }
    });
  }

  render() {
    const t = theme();
    const d = this.data;

    const colorOf = (s) =>
      s === "dead" ? t.blocked : s === "ok" ? t.ansi2 : t.dim;

    const group = (text, count) =>
      h_flex()
        .h(24)
        .flex_none()
        .px(10)
        .gap(6)
        .items_center()
        .child(div().text_size(12).text_color(t.dim).child(text))
        .when(count > 0, (el) =>
          el.child(div().text_size(10.5).text_color(t.dim).child(String(count)))
        );

    // 行: 短横线 + 文字 (不用竖线, 保持简洁)
    const treeRow = (name, color) => {
      return h_flex()
        .h(ROW_H)
        .flex_none()
        .relative()
        .items_center()
        .child(
          div()
            .absolute()
            .left(INDENT)
            .top(Math.floor(ROW_H / 2))
            .w(7)
            .h(1)
            .bg(t.border)
        )
        .child(
          div().pl(INDENT + 10).text_size(12).text_color(color).child(name)
        );
    };

    // 空组直接不渲染 (返回空数组)
    const section = (title, list) => {
      if (!list.length) return [];
      const out = [group(title, list.length)];
      list.forEach((it) => out.push(treeRow(it.name, colorOf(it.state))));
      return out;
    };

    // git 也只在有仓库时显示
    const gitSection = d.git
      ? [
          group("git", 0),
          treeRow(
            clip(d.git.branch, 22) + (d.git.dirty ? " *" : ""),
            t.foreground
          ),
        ]
      : [];

    const body = v_flex()
      .id("ss-body")
      .flex_1()
      .min_h(0)
      .overflow_y_scrollbar()
      .pt(2)
      .pb(6)
      .children(section("mcp", d.mcp))
      .children(section("skills", d.skills))
      .children(section("ext", d.ext))
      .children(gitSection);

    const deadCount = d.mcp.filter((x) => x.state === "dead").length;
    const dot = deadCount > 0 ? t.blocked : d.mcp.length ? t.ansi2 : t.dim;

    // ── 自适应高度: 算出内容需要的高度, 推给布局节点
    //   header 34 + 每组 (24 标题 + n×19 行) + 上下 padding 8
    const rows =
      d.mcp.length + d.skills.length + d.ext.length + (d.git ? 1 : 0);
    const groups =
      (d.mcp.length ? 1 : 0) +
      (d.skills.length ? 1 : 0) +
      (d.ext.length ? 1 : 0) +
      (d.git ? 1 : 0);
    const want = 34 + groups * 24 + rows * ROW_H + 8;
    const clamped = Math.max(70, Math.min(420, want));
    if (this.lastH !== clamped) {
      this.lastH = clamped;
      // 下一帧再发, 避免渲染期间改布局
      queueMicrotask(() => {
        try {
          run("layout.resize", { id: "session-panel", px: clamped });
        } catch {}
      });
    }

    return v_flex()
      .id("session-status")
      .size_full()
      .min_h(0)
      .rounded(10)
      .overflow_hidden()
      .bg(t.background)
      .border_1()
      .border_color(t.border)
      .text_color(t.foreground)
      .child(
        h_flex()
          .h(34)
          .flex_none()
          .px(12)
          .items_center()
          .gap(8)
          .border_b(1)
          .border_color(t.border)
          .child(div().text_size(12.5).text_color(t.foreground).child("Session"))
          .child(div().flex_1())
          .when(Boolean(this.err), (el) =>
            el.child(div().text_size(10).text_color(t.blocked).child("ERR"))
          )
          .when(deadCount > 0, (el) =>
            el
              .child(div().text_size(11).text_color(t.blocked).child(`${deadCount} dead`))
          )
          .child(div().size(6).rounded(3).bg(dot))
      )
      .child(body);
  }
}
