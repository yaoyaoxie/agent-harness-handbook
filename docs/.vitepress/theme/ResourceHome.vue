<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { data as cards } from '../data/cards.data'

const CATEGORY_ICONS: Record<string, string> = {
  导读: '🧭',
  核心组件: '⚙️',
  经典案例: '🔍',
  论文精读: '📄',
  实践指南: '🛠️',
  求职与JD: '💼',
  学习论坛: '💬',
  资源: '📚'
}

// 学习路径：本站内容的三条主线，与 /guide/paths 对应
const PATHS = [
  {
    icon: '🎯',
    name: '求职冲刺',
    duration: '约 2 周',
    desc: '1–3 个月内要面试：直奔 JD 对标、简历改写与面试题库，每一页都对着大厂考点。',
    link: '/guide/paths'
  },
  {
    icon: '📈',
    name: '系统转行',
    duration: '约 6 周',
    desc: '时间充裕想打牢底子：从导读到实践分周推进，每周有明确的检验标准。',
    link: '/guide/paths'
  },
  {
    icon: '🔖',
    name: '案头速查',
    duration: '随用随查',
    desc: '在职建造者不通读：按「问题 → 页面」索引即查即走，把它当工具书用。',
    link: '/guide/paths'
  }
]

const categories = computed(() => [...new Set(cards.map((c) => c.category))])
const featured = computed(() => cards.filter((c) => c.recommended))

const activeCategory = ref('全部')
const query = ref('')
const showFavorites = ref(false)
const favorites = ref<string[]>([])

onMounted(() => {
  try {
    favorites.value = JSON.parse(localStorage.getItem('ah-favorites') || '[]')
  } catch {
    favorites.value = []
  }
})

function toggleFav(link: string) {
  const i = favorites.value.indexOf(link)
  if (i >= 0) favorites.value.splice(i, 1)
  else favorites.value.push(link)
  localStorage.setItem('ah-favorites', JSON.stringify(favorites.value))
}

const filtered = computed(() =>
  cards.filter((c) => {
    if (showFavorites.value && !favorites.value.includes(c.link)) return false
    if (activeCategory.value !== '全部' && c.category !== activeCategory.value)
      return false
    if (query.value.trim()) {
      const q = query.value.trim().toLowerCase()
      const haystack = (c.title + c.desc + c.tags.join(' ')).toLowerCase()
      if (!haystack.includes(q)) return false
    }
    return true
  })
)

function categoryIcon(category: string) {
  return CATEGORY_ICONS[category] || '📄'
}

const emptyText = computed(() =>
  showFavorites.value
    ? '还没有收藏内容，点击卡片右上角的星标收藏'
    : '没有匹配的内容，换个关键词或分类试试'
)
</script>

<template>
  <div class="rh">
    <!-- Hero -->
    <header class="rh-hero">
      <p class="rh-kicker">AGENT HARNESS HANDBOOK</p>
      <h1 class="rh-title">Agent Harness 手册</h1>
      <p class="rh-subtitle">
        模型之外，让智能体真正干活的那套系统 —— 智能体循环 · 上下文工程 · 工具系统 · 记忆 · 子代理 · 安全边界
      </p>
      <div class="rh-actions">
        <a href="/guide/paths" class="rh-cta primary">选一条学习路径 →</a>
        <a href="/guide/what-is-harness" class="rh-cta">什么是 Agent Harness</a>
      </div>
      <p class="rh-metaphor">
        如果把大语言模型比作引擎，<strong>Harness（骨架 / 挽具）就是把引擎变成一辆车所需要的一切</strong>——传动、转向、仪表盘、刹车。<a href="/guide/what-is-harness">深入了解 →</a>
      </p>
    </header>

    <!-- 学习路径 -->
    <section class="rh-section">
      <h2 class="rh-section-title">从哪条路开始</h2>
      <p class="rh-section-sub">40+ 篇内容不是要你通读的图书馆，而是可以按需组合的路线图</p>
      <div class="rh-paths">
        <a v-for="p in PATHS" :key="p.name" :href="p.link" class="rh-path">
          <div class="rh-path-head">
            <span class="rh-path-icon">{{ p.icon }}</span>
            <span class="rh-path-name">{{ p.name }}</span>
            <span class="rh-path-duration">{{ p.duration }}</span>
          </div>
          <p class="rh-path-desc">{{ p.desc }}</p>
          <span class="rh-path-go">查看路线 →</span>
        </a>
      </div>
    </section>

    <!-- 编辑推荐 -->
    <section class="rh-section">
      <h2 class="rh-section-title">✨ 编辑推荐</h2>
      <p class="rh-section-sub">只读十篇的话，读这些</p>
      <div class="rh-featured">
        <a
          v-for="(card, i) in featured"
          :key="card.link"
          :href="card.link"
          class="rh-fcard"
        >
          <span class="rh-fcard-num">{{ String(i + 1).padStart(2, '0') }}</span>
          <div class="rh-fcard-body">
            <h3 class="rh-fcard-title">
              {{ categoryIcon(card.category) }} {{ card.title }}
            </h3>
            <p class="rh-fcard-desc">{{ card.desc }}</p>
            <span class="rh-fcard-cat">{{ card.category }}</span>
          </div>
        </a>
      </div>
    </section>

    <!-- 全站浏览 -->
    <section class="rh-section">
      <h2 class="rh-section-title">全站内容</h2>
      <p class="rh-section-sub">按模块浏览，或直接搜索</p>

      <div class="rh-browse-bar">
        <nav class="rh-cats" aria-label="内容分类">
          <button
            class="rh-pill"
            :class="{ active: activeCategory === '全部' && !showFavorites }"
            @click="((activeCategory = '全部'), (showFavorites = false))"
          >
            全部
          </button>
          <button
            v-for="cat in categories"
            :key="cat"
            class="rh-pill"
            :class="{ active: activeCategory === cat && !showFavorites }"
            @click="((activeCategory = cat), (showFavorites = false))"
          >
            {{ categoryIcon(cat) }} {{ cat }}
          </button>
        </nav>
        <div class="rh-browse-tools">
          <input
            v-model="query"
            class="rh-search"
            type="search"
            placeholder="搜索内容…"
            aria-label="搜索内容"
          />
          <button
            class="rh-pill rh-fav-pill"
            :class="{ active: showFavorites }"
            @click="showFavorites = !showFavorites"
          >
            ⭐ 收藏
            <span class="rh-fav-count">{{ favorites.length }}</span>
          </button>
        </div>
      </div>

      <div v-if="filtered.length" class="rh-grid">
        <article
          v-for="(card, i) in filtered"
          :key="card.link"
          class="rh-card"
          :style="{ animationDelay: Math.min(i, 12) * 35 + 'ms' }"
        >
          <button
            class="rh-star"
            :class="{ starred: favorites.includes(card.link) }"
            :aria-label="favorites.includes(card.link) ? '取消收藏' : '收藏'"
            @click.prevent="toggleFav(card.link)"
          >
            {{ favorites.includes(card.link) ? '★' : '☆' }}
          </button>
          <a :href="card.link" class="rh-card-link">
            <span v-if="card.recommended" class="rh-badge">✨ 推荐</span>
            <h3 class="rh-card-title">
              <span class="rh-card-icon">{{ categoryIcon(card.category) }}</span>
              {{ card.title }}
            </h3>
            <p class="rh-card-desc">{{ card.desc }}</p>
            <div class="rh-card-tags">
              <span v-for="tag in card.tags" :key="tag" class="rh-tag">{{ tag }}</span>
            </div>
          </a>
        </article>
      </div>
      <p v-else class="rh-empty">{{ emptyText }}</p>
    </section>
  </div>
</template>
