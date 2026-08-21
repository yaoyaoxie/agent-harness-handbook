/*!
 * tracker.js v2 — 轻量自托管访问统计（无 Cookie、无指纹）
 *
 * 接入方式（一行代码）：
 *   <script defer src="https://harness.zhigouread.com/t/tracker.js" data-site="你的项目名"></script>
 *
 * v2 新增（对接入方透明，无需改代码）：
 *   - 停留时长：页面隐藏/关闭时上报本次停留秒数
 *   - 滚动深度：记录本次访问最深滚动到页面的百分之几
 *
 * 原理：向采集端点发 GET 图片请求，参数携带页面/来源/停留/深度。
 *       GET 图片不受 CORS 限制，支持任意第三方域名页面。
 * 隐私：不写 Cookie、不读 localStorage、不做设备指纹。
 */
(function () {
  'use strict';
  var d = document, w = window, n = navigator;
  var cur = d.currentScript;
  if (!cur) return;

  var site = cur.getAttribute('data-site');
  if (!site || !/^[a-z0-9][a-z0-9-]*$/.test(site)) {
    if (w.console) console.error('[tracker] data-site 缺失或格式不正确（仅允许小写字母/数字/连字符）');
    return;
  }

  var endpoint = cur.getAttribute('data-endpoint');
  if (!endpoint) {
    var m = cur.src.match(/^(https?:\/\/[^/]+)/);
    if (!m) return;
    endpoint = m[1] + '/t/hit';
  }

  var lastPath = null;
  var startTs = 0;        // 本次页面浏览开始时间
  var maxDepth = 0;       // 本次最深滚动百分比
  var leaveSent = false;  // leave 事件只发一次

  function baseQuery() {
    return 's=' + encodeURIComponent(site) +
           '&p=' + encodeURIComponent(w.location.pathname + w.location.search) +
           '&r=' + encodeURIComponent(d.referrer || '') +
           '&w=' + (w.screen && screen.width || 0) +
           '&l=' + encodeURIComponent(n.language || '');
  }

  function fire(q) {
    var img = new Image();
    img.src = endpoint + '?' + q + '&_=' + Date.now();
  }

  function calcDepth() {
    var doc = d.documentElement, body = d.body;
    var full = Math.max(doc.scrollHeight, body ? body.scrollHeight : 0, doc.clientHeight);
    var seen = (w.pageYOffset || doc.scrollTop || 0) + w.innerHeight;
    if (full > 0) {
      var pct = Math.min(100, Math.round((seen / full) * 100));
      if (pct > maxDepth) maxDepth = pct;
    }
  }

  function sendView() {
    var p = w.location.pathname + w.location.search;
    if (p === lastPath) return;
    // 路径切换视为新的一次浏览：先结清上一页
    if (lastPath !== null) sendLeave();
    lastPath = p;
    startTs = Date.now();
    maxDepth = 0;
    leaveSent = false;
    calcDepth();
    fire(baseQuery() + '&e=view');
  }

  function sendLeave() {
    if (leaveSent || lastPath === null || !startTs) return;
    leaveSent = true;
    var t = Math.round((Date.now() - startTs) / 1000);
    if (t < 0) t = 0;
    if (t > 7200) t = 7200;   // 截断异常值（后台挂太久）
    fire(baseQuery() + '&e=leave&t=' + t + '&d=' + maxDepth);
  }

  // 滚动深度（被动监听，节流）
  var ticking = false;
  w.addEventListener('scroll', function () {
    if (ticking) return;
    ticking = true;
    setTimeout(function () { calcDepth(); ticking = false; }, 500);
  }, { passive: true });

  // 页面隐藏或关闭时结清本次浏览
  d.addEventListener('visibilitychange', function () {
    if (d.visibilityState === 'hidden') sendLeave();
  });
  w.addEventListener('pagehide', sendLeave);

  // 首次浏览
  if (d.readyState === 'complete' || d.readyState === 'interactive') {
    sendView();
  } else {
    w.addEventListener('DOMContentLoaded', sendView);
  }

  // SPA 路由支持
  var origPush = history.pushState;
  history.pushState = function () {
    origPush.apply(history, arguments);
    setTimeout(sendView, 0);
  };
  w.addEventListener('popstate', function () { setTimeout(sendView, 0); });
  w.addEventListener('hashchange', function () { setTimeout(sendView, 0); });
})();
