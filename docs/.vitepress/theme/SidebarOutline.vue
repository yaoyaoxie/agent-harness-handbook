<script setup>
// 把当前页面的 h2/h3 章节目录渲染进左侧导航（sidebar-nav-after 插槽）。
// 注意：VitePress 在 outline:false 时不会收集 page.headers，
// 因此这里直接从渲染后的 DOM 提取标题，与 outline 设置解耦。
import { ref, onMounted, watch, nextTick } from 'vue'
import { useRoute } from 'vitepress'

const chapters = ref([])
const route = useRoute()

function collect() {
  const els = document.querySelectorAll('.vp-doc h2[id], .vp-doc h3[id]')
  chapters.value = Array.from(els).map((el) => ({
    level: el.tagName === 'H2' ? 2 : 3,
    title: el.textContent.trim(),
    link: `#${el.id}`
  }))
}

onMounted(collect)
watch(() => route.path, () => nextTick(collect))
</script>

<template>
  <div v-if="chapters.length" class="sidebar-chapters">
    <div class="sc-title">本页章节</div>
    <a
      v-for="c in chapters"
      :key="c.link"
      :href="c.link"
      class="sc-link"
      :class="{ 'sc-sub': c.level === 3 }"
      >{{ c.title }}</a
    >
  </div>
</template>

<style scoped>
.sidebar-chapters {
  margin-top: 16px;
  padding-top: 12px;
  border-top: 1px solid var(--vp-c-divider);
}

.sc-title {
  padding: 0 12px 6px;
  font-size: 13px;
  font-weight: 600;
  color: var(--vp-c-text-2);
}

.sc-link {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  padding: 4px 12px;
  font-size: 13px;
  line-height: 1.5;
  color: var(--vp-c-text-2);
  border-radius: 6px;
  transition:
    color 0.2s ease,
    background-color 0.2s ease;
}

.sc-link:hover {
  color: var(--vp-c-brand-1);
  background-color: var(--vp-c-brand-soft);
}

.sc-sub {
  padding-left: 26px;
  font-size: 12.5px;
}
</style>
