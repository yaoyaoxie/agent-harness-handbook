<script setup>
// 圈子式论坛（单一信息流 + 可选话题标签）。
// 所有发言进同一条 Twikoo 讨论串；话题标签（#提问 等）只是前端筛选器，
// 不带标签的发言留在「全部」里，不拦任何人。
import { ref, onMounted, onUnmounted } from 'vue'
import { TWIKOO_ENV_ID, TWIKOO_SRC, patchCloudbaseAuth } from './twikoo-env'

const THREAD_PATH = '/community/circle'

const TAGS = [
  { key: 'all', name: '全部' },
  { key: '提问', name: '#提问' },
  { key: '打卡', name: '#打卡' },
  { key: '碎碎念', name: '#碎碎念' },
  { key: '许愿', name: '#许愿' }
]

const active = ref('all')
const wrap = ref(null)
const el = ref(null)
const emptyFilter = ref(false)

// 前端标签筛选：遍历顶层评论，按正文是否含标签显隐。
// 注意：twikoo.init 会替换掉挂载点元素本身，所以查询和观察都要走外层 wrap。
function applyFilter() {
  const root = wrap.value
  if (!root) return
  const comments = root.querySelectorAll('.tk-comments-container > .tk-comment')
  let visible = 0
  comments.forEach((c) => {
    const text = c.querySelector('.tk-content')?.textContent || ''
    const show = active.value === 'all' || text.includes('#' + active.value)
    c.style.display = show ? '' : 'none'
    if (show) visible++
  })
  emptyFilter.value = comments.length > 0 && visible === 0
  // 顺手把发布框占位文案改成圈子语境
  root
    .querySelector('.tk-input')
    ?.setAttribute(
      'placeholder',
      '随手写点什么… 愿意的话带上话题：#提问 #打卡 #碎碎念 #许愿，没带也不拦你'
    )
}

function switchTag(key) {
  active.value = key
  applyFilter()
}

const initError = ref('')

let observer = null

async function initTwikoo() {
  if (!window.twikoo || !el.value) return
  el.value.innerHTML = ''
  patchCloudbaseAuth()
  try {
    await window.twikoo.init({ envId: TWIKOO_ENV_ID, el: el.value, path: THREAD_PATH })
    initError.value = ''
  } catch (e) {
    // 多为 CloudBase 控制台未开启「匿名登录」导致，恢复后刷新即可
    console.warn('[ForumFeed] twikoo init failed:', e)
    initError.value = '圈子开通中，还差最后一步配置。刷新没好的话，先去微信群里喊一声。'
  }
  // 评论异步渲染 / 分页加载后都要重新套用筛选
  observer?.disconnect()
  observer = new MutationObserver(() => applyFilter())
  observer.observe(wrap.value, { childList: true, subtree: true })
}

onMounted(() => {
  if (window.twikoo) {
    initTwikoo()
    return
  }
  let s = document.querySelector('script[data-twikoo]')
  if (s) {
    s.addEventListener('load', initTwikoo)
    return
  }
  s = document.createElement('script')
  s.src = TWIKOO_SRC
  s.dataset.twikoo = ''
  s.onload = initTwikoo
  document.head.appendChild(s)
})

onUnmounted(() => observer?.disconnect())
</script>

<template>
  <div class="ff">
    <div class="ff-main">
      <nav class="ff-tabs" aria-label="按话题筛选">
        <button
          v-for="t in TAGS"
          :key="t.key"
          class="ff-tab"
          :class="{ active: active === t.key }"
          @click="switchTag(t.key)"
        >
          {{ t.name }}
        </button>
      </nav>
      <p class="ff-hint">
        这里是朋友圈，不是办事大厅——随手写，不用选版块、不用管格式。发言即匿名，对事不对人。
      </p>
      <div ref="wrap" class="ff-feed-host">
        <div ref="el" class="ff-feed" />
        <p v-if="initError" class="ff-init-error">{{ initError }}</p>
      </div>
      <p v-if="emptyFilter" class="ff-empty">
        还没有带「#{{ active }}」话题的发言，来发第一条？
      </p>
    </div>

    <aside class="ff-rail">
      <div class="ff-card">
        <h4 class="ff-card-title">规则（就两条）</h4>
        <ol class="ff-rules">
          <li><strong>对事不对人。</strong>没有愚蠢的问题，只有没写清楚的问题。</li>
          <li><strong>不发广告、不灌水、不转载侵权内容。</strong></li>
        </ol>
        <details class="ff-details">
          <summary>想让答案来得更快？</summary>
          <pre class="ff-template">提问带上上下文效果最好：
【我在哪】页面/教程名 + 具体小节
【我想做什么】一句话目标
【发生了什么】报错原文 / 实际现象
【我试过什么】已经尝试的排查</pre>
        </details>
      </div>
      <div class="ff-card">
        <h4 class="ff-card-title">话题怎么用</h4>
        <ul class="ff-rules">
          <li><strong>#提问</strong> 学习或动手卡住了</li>
          <li><strong>#打卡</strong> 记录三条路线上的进度</li>
          <li><strong>#许愿</strong> 想让手册讲的主题，热度高的优先写</li>
          <li><strong>#碎碎念</strong> 其他一切——读后感、踩坑、晒作品</li>
        </ul>
      </div>
      <div class="ff-card">
        <h4 class="ff-card-title">微信群</h4>
        <p class="ff-wx-text">扫码加站主微信，备注「harness」，拉你进学习群。</p>
        <img src="/wechat-qr.png" alt="微信群二维码" class="ff-wx-qr" />
        <p class="ff-wx-note">群里做即时讨论和通知；好内容还是发在这里，方便沉淀和被搜索到。</p>
      </div>
    </aside>
  </div>
</template>
