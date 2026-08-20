<script setup>
import DefaultTheme from 'vitepress/theme'
import { useData } from 'vitepress'
import { computed } from 'vue'

const { frontmatter, page, theme } = useData()

// ===== GitBook 风面包屑：首页 > 栏目 > 子组（当前页标题由下方大标题呈现）=====
const CATEGORY_MAP = {
  guide: '导读',
  components: '核心组件',
  'case-studies': '经典案例',
  papers: '论文精读',
  practice: '实践指南',
  career: '求职与JD',
  community: '学习论坛',
  resources: '资源'
}

function toLink(rel) {
  const p = rel.replace(/\.md$/, '')
  if (p === 'index') return '/'
  if (p.endsWith('/index')) return '/' + p.slice(0, -'index'.length)
  return '/' + p
}

// 在侧边栏配置里沿分组向下找当前页，收集祖先分组名作为面包屑路径
function findTrail(items, target, acc) {
  for (const it of items) {
    if (it.link === target) return acc
    if (Array.isArray(it.items)) {
      const found = findTrail(it.items, target, [...acc, it.text])
      if (found) return found
    }
  }
  return null
}

const breadcrumb = computed(() => {
  const rel = page.value.relativePath || ''
  if (!rel || rel === 'index.md') return []
  const seg = rel.split('/')[0]
  const groups = theme.value.sidebar?.['/' + seg + '/']
  if (Array.isArray(groups)) {
    const target = toLink(rel)
    for (const g of groups) {
      if (!Array.isArray(g.items)) continue
      const trail = findTrail(g.items, target, g.link ? [] : [g.text])
      if (trail) return trail
    }
  }
  return CATEGORY_MAP[seg] ? [CATEGORY_MAP[seg]] : []
})
</script>

<template>
  <DefaultTheme.Layout>
    <template #doc-before>
      <div class="doc-header">
        <nav v-if="breadcrumb.length" class="breadcrumb" aria-label="面包屑导航">
          <a class="bc-link" href="/">首页</a>
          <template v-for="(item, i) in breadcrumb" :key="i">
            <span class="bc-sep">›</span>
            <span class="bc-text">{{ item }}</span>
          </template>
        </nav>
        <h1 class="dh-title">{{ frontmatter.title }}</h1>
      </div>
      <p v-if="frontmatter.abstract || frontmatter.description" class="page-abstract">
        <span class="pa-label">本页速览</span>
        {{ frontmatter.abstract || frontmatter.description }}
      </p>
      <p v-if="frontmatter.dataAsOf" class="data-asof">
        本页含时效性内容，数据截止于 <strong>{{ frontmatter.dataAsOf }}</strong
        >；JD、价格、产品功能等信息可能已变化，引用前请核对原始出处。
      </p>
    </template>
  </DefaultTheme.Layout>
</template>

<style scoped>
.page-abstract {
  margin-bottom: 16px;
  color: var(--vp-c-text-2);
  font-size: 16.5px;
  line-height: 1.9;
}

.pa-label {
  display: inline-block;
  margin-right: 8px;
  font-weight: 700;
  color: var(--vp-c-text-1);
}

.data-asof {
  margin-bottom: 16px;
  color: var(--vp-c-text-3);
  font-size: 14px;
  line-height: 1.7;
}
</style>
