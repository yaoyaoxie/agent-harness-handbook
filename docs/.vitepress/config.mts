import { defineConfig } from 'vitepress'

// 部署到 GitHub Pages 项目页时由 CI 注入（如 /repo-name/）；本地开发与预览保持 /
const base = process.env.VITEPRESS_BASE || '/'
// TODO(部署后替换): 改成站点的最终公网地址，用于 sitemap 与 og:url
const siteUrl = process.env.SITE_URL || 'https://agent-harness-handbook.edgeone.dev'

export default defineConfig({
  lang: 'zh-CN',
  title: 'Agent Harness 手册',
  description: '系统拆解 AI 智能体骨架（Agent Harness）的设计与实现：智能体循环、上下文工程、工具系统、记忆、子代理、权限安全与评测',
  cleanUrls: true,
  lastUpdated: true,
  base,

  sitemap: {
    hostname: siteUrl
  },

  head: [
    ['meta', { name: 'keywords', content: 'Agent Harness, AI Agent, 智能体, 上下文工程, LLM, Claude Code, SWE-agent' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'Agent Harness 手册' }],
    ['meta', { property: 'og:description', content: '系统拆解 AI 智能体骨架（Agent Harness）的设计与实现' }],
    ['meta', { property: 'og:locale', content: 'zh_CN' }],
    ['meta', { property: 'og:url', content: siteUrl }],
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}logo.svg` }]
  ],

  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'Agent Harness 手册',

    nav: [
      { text: '首页', link: '/' },
      { text: '导读', link: '/guide/what-is-harness' },
      { text: '核心组件', link: '/components/agent-loop' },
      { text: '经典案例', link: '/case-studies/claude-code' },
      { text: '论文精读', link: '/papers/' },
      { text: '实践指南', link: '/practice/build-your-own' },
      { text: '求职与 JD 分析', link: '/career/' },
      { text: '学习论坛', link: '/community/' },
      { text: '资源', link: '/resources/glossary' }
    ],

    sidebar: {
      '/guide/': [
        {
          text: '导读',
          collapsed: false,
          items: [
            {
              text: '先看这里',
              collapsed: false,
              items: [
                { text: '学习路径：三条路线', link: '/guide/paths' },
                { text: '什么是 Agent Harness', link: '/guide/what-is-harness' }
              ]
            },
            {
              text: '建立框架',
              collapsed: false,
              items: [
                { text: '模型 vs 骨架：为什么 Harness 决定上限', link: '/guide/model-vs-harness' },
                { text: '演进简史', link: '/guide/history' },
                { text: '总体架构解剖', link: '/guide/anatomy' }
              ]
            }
          ]
        }
      ],
      '/components/': [
        {
          text: '核心组件',
          collapsed: false,
          items: [
            {
              text: '运转核心',
              collapsed: false,
              items: [
                { text: '智能体循环（Agent Loop）', link: '/components/agent-loop' },
                { text: '上下文工程', link: '/components/context-engineering' },
                { text: '工具系统与 MCP', link: '/components/tools' },
                { text: '规划与任务分解', link: '/components/planning' },
                { text: '记忆系统', link: '/components/memory' }
              ]
            },
            {
              text: '协作与扩展',
              collapsed: false,
              items: [
                { text: '子代理与多智能体编排', link: '/components/subagents' },
                { text: '技能与知识注入', link: '/components/skills' },
                { text: '模型选型与成本工程', link: '/components/model-routing' }
              ]
            },
            {
              text: '安全与质量',
              collapsed: false,
              items: [
                { text: '权限、安全与人类在环', link: '/components/permissions' },
                { text: '评测与可观测性', link: '/components/observability' }
              ]
            }
          ]
        }
      ],
      '/case-studies/': [
        {
          text: '经典案例',
          collapsed: false,
          items: [
            {
              text: '国外产品',
              collapsed: false,
              items: [
                { text: 'Claude Code', link: '/case-studies/claude-code' },
                { text: 'Cursor', link: '/case-studies/cursor' },
                { text: 'SWE-agent', link: '/case-studies/swe-agent' },
                { text: 'OpenHands', link: '/case-studies/openhands' },
                { text: 'Aider', link: '/case-studies/aider' },
                { text: 'Devin', link: '/case-studies/devin' },
                { text: 'LangGraph', link: '/case-studies/langgraph' }
              ]
            },
            {
              text: '国内产品',
              collapsed: false,
              items: [
                { text: '扣子（Coze）', link: '/case-studies/coze' },
                { text: 'Manus', link: '/case-studies/manus' },
                { text: 'Dify', link: '/case-studies/dify' }
              ]
            }
          ]
        }
      ],
      '/papers/': [
        {
          text: '论文精读',
          collapsed: false,
          items: [
            { text: '从这里开始', link: '/papers/' },
            { text: '阅读路径', link: '/papers/paths' },
            { text: '论文地图', link: '/papers/map' },
            { text: '经典论文精读', link: '/papers/core-papers' },
            { text: '前沿进展', link: '/papers/frontier' },
            { text: '阅读纪律与 FAQ', link: '/papers/faq' }
          ]
        }
      ],
      '/practice/': [
        {
          text: '实践指南',
          collapsed: false,
          items: [
            {
              text: '动手路线',
              collapsed: false,
              items: [
                { text: '从零构建一个最小 Harness', link: '/practice/build-your-own' },
                { text: '渐进式教程：三版跑起来', link: '/practice/harness-tutorial' },
                { text: '从零搭一套 Agent 评测', link: '/practice/evals-in-practice' },
                { text: '作品集项目', link: '/practice/portfolio-projects' }
              ]
            },
            {
              text: '方法与决策',
              collapsed: false,
              items: [
                { text: '框架与平台怎么选', link: '/practice/framework-comparison' },
                { text: '写好 CLAUDE.md / AGENTS.md', link: '/practice/writing-claude-md' },
                { text: 'Harness 设计原则', link: '/practice/design-principles' },
                { text: '常见陷阱与反模式', link: '/practice/pitfalls' }
              ]
            }
          ]
        }
      ],
      '/career/': [
        {
          text: '求职与 JD 分析',
          collapsed: false,
          items: [
            {
              text: '看清市场',
              collapsed: false,
              items: [
                { text: '模块导读与岗位版图', link: '/career/' },
                { text: 'JD 清单：国内外大厂在招岗位', link: '/career/jd-list' },
                { text: 'JD 知识点拆解', link: '/career/knowledge-map' }
              ]
            },
            {
              text: '准备自己',
              collapsed: false,
              items: [
                { text: '能力对标：简历该突出什么', link: '/career/resume-analysis' },
                { text: '面试题库', link: '/career/interview-questions' }
              ]
            }
          ]
        }
      ],
      '/community/': [
        {
          text: '学习论坛',
          collapsed: false,
          items: [{ text: '圈子', link: '/community/' }]
        }
      ],
      '/resources/': [
        {
          text: '资源',
          collapsed: false,
          items: [
            { text: '术语表', link: '/resources/glossary' },
            { text: '精选资源清单', link: '/resources/awesome' },
            { text: '系统提示词档案', link: '/resources/prompt-archive' }
          ]
        }
      ]
    },

    outline: {
      level: [2, 3],
      label: '本页'
    },

    search: {
      provider: 'local',
      options: {
        translations: {
          button: { buttonText: '搜索', buttonAriaLabel: '搜索' },
          modal: {
            displayDetails: '显示详细列表',
            resetButtonTitle: '重置搜索',
            backButtonTitle: '关闭搜索',
            noResultsText: '没有相关结果',
            footer: {
              selectText: '选择',
              selectKeyAriaLabel: '输入',
              navigateText: '导航',
              navigateUpKeyAriaLabel: '上箭头',
              navigateDownKeyAriaLabel: '下箭头',
              closeText: '关闭',
              closeKeyAriaLabel: 'ESC'
            }
          }
        }
      }
    },

    docFooter: { prev: '上一页', next: '下一页' },
    lastUpdatedText: '最后更新',
    returnToTopLabel: '返回顶部',
    sidebarMenuLabel: '菜单',
    darkModeSwitchLabel: '外观',
    lightModeSwitchTitle: '切换到浅色模式',
    darkModeSwitchTitle: '切换到深色模式',

    socialLinks: []
  }
})
