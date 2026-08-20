import { createContentLoader } from 'vitepress'

export interface Card {
  title: string
  link: string
  desc: string
  category: string
  tags: string[]
  recommended: boolean
}

declare const data: Card[]
export { data }

const CATEGORY_MAP: Record<string, string> = {
  guide: '导读',
  components: '核心组件',
  'case-studies': '经典案例',
  papers: '论文精读',
  practice: '实践指南',
  career: '求职与JD',
  community: '学习论坛',
  resources: '资源'
}

// 分类在首页的排列顺序
const CATEGORY_ORDER = Object.values(CATEGORY_MAP)

export default createContentLoader(
  '{guide,components,case-studies,papers,practice,career,community,resources}/*.md',
  {
    transform(raw): Card[] {
      return raw
        .map((page) => {
          const seg = page.url.split('/')[1]
          const category = CATEGORY_MAP[seg] || seg
          return {
            title: page.frontmatter.title || page.url,
            link: page.url,
            desc: page.frontmatter.description || '',
            category,
            tags: Array.isArray(page.frontmatter.tags)
              ? page.frontmatter.tags
              : [category],
            recommended: page.frontmatter.recommended === true
          }
        })
        // 只收录写了 description 的正式内容页
        .filter((card) => card.desc)
        .sort(
          (a, b) =>
            CATEGORY_ORDER.indexOf(a.category) -
              CATEGORY_ORDER.indexOf(b.category) || a.title.localeCompare(b.title, 'zh-CN')
        )
    }
  }
)
