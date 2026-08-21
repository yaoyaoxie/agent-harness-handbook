/*!
 * tracker.js — 轻量自托管访问统计（无 Cookie、无指纹、~1KB）
 *
 * 接入方式（一行代码）：
 *   <script defer src="https://harness.zhigouread.com/t/tracker.js" data-site="你的项目名"></script>
 *
 * 可选属性：
 *   data-site      项目标识，必填。规则：小写字母/数字/连字符，如 my-blog
 *   data-endpoint  自定义采集端点，默认从 script src 自动推导（…/t/hit）
 *
 * 原理：向采集端点发一张 1 像素的 GET 图片请求，参数携带页面路径/来源等。
 *       GET 图片请求不受 CORS 限制，支持任意第三方域名页面。
 *       已内置 SPA 支持（pushState / popstate 切换页面也会上报）。
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

  function send() {
    var p = w.location.pathname + w.location.search;
    if (p === lastPath) return;   // 同一路径不重复上报
    lastPath = p;
    var q = 's=' + encodeURIComponent(site) +
            '&p=' + encodeURIComponent(p) +
            '&r=' + encodeURIComponent(d.referrer || '') +
            '&w=' + (w.screen && screen.width || 0) +
            '&l=' + encodeURIComponent(n.language || '');
    var img = new Image();
    img.src = endpoint + '?' + q + '&_=' + Date.now();
  }

  if (d.readyState === 'complete' || d.readyState === 'interactive') {
    send();
  } else {
    w.addEventListener('DOMContentLoaded', send);
  }

  // SPA 路由支持
  var origPush = history.pushState;
  history.pushState = function () {
    origPush.apply(history, arguments);
    setTimeout(send, 0);
  };
  w.addEventListener('popstate', function () { setTimeout(send, 0); });
  w.addEventListener('hashchange', function () { setTimeout(send, 0); });
})();
