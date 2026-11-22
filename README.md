# Quarto 科研文档模板

面向中英文科研文档的项目起点，支持 HTML、Word 和由 LaTeX 直接生成的 PDF。两份示例既展示写法，也用于回归检查排版。

## 开始写作

```powershell
mkdir my-document
cd my-document
quarto use template wiederholung/quarto-template
quarto render template-zh.qmd --to docx
quarto render template-zh.qmd --to pdf
quarto preview template-zh.qmd --to html
```

在模板仓库中运行 `quarto render --to all` 可生成两份示例的全部六种输出。逐篇写作时，使用上面的单篇命令。

在空目录按提示选择当前目录并确认安装作者扩展。中英文示例会保留原名，可按需要重命名并改写其中一份。安装完成即可渲染。`docs/使用说明.md` 随项目复制，其中提供可选的 Git 配置。本地试用模板副本时，可将仓库名换为本地路径。

新项目仅复制写作配置、两份 QMD、样式与扩展快照、示例文献和图片，以及 `docs/使用说明.md`。`.quartoignore` 排除 `tests/`、`scripts/` 和开发设计、验证文档；它们保留在模板仓库供维护使用。

## 配置分工

| 位置 | 职责 |
|---|---|
| `_quarto.yml` | 输出目录、IEEE 引用样式、章节编号、HTML 目录、PDF 页边距及格式过滤器 |
| `template-zh.qmd` / `template-en.qmd` | 标题、作者、ORCID、语言、日期、文献文件、HTML 主题、Word 参考文档和 PDF 文档类 |
| `styles/` | DOCX、CSL、HTML 样式与版本来源；旧 LaTeX 覆盖保留但停用 |
| `_extensions/` | 当前项目使用的完整作者扩展快照 |
| `bibliography/` / `figures/` | 文献数据与插图 |
| `output/` | 生成结果，不提交到 Git |

没有限定 `project.render`，因此新增 QMD 不需要修改一份文件名单。文档总标题写在 YAML 的 `title` 中，正文从 `#` 开始，依次用 `##`、`###` 表示下级标题。项目不设置 `shift-heading-level-by`，让源文件与输出的正文层级直接对应：Word 使用“标题 1、标题 2……”；当前文章类 PDF 使用 `section`、`subsection` 等。标题中不手写编号；各格式的章节、图表、公式和文献编号均由 Quarto 渲染生成；参考文献写为 `# 参考文献 {.unnumbered}`（英文为 `# References {.unnumbered}`）。

两份 QMD 各自在 `format.html.theme` 中选择 `litera`。HTML 默认有目录，图片、样式和脚本作为配套资源输出。分享网页时保留 `output/` 下的相对目录结构；需要单文件时设置 `embed-resources: true`。

## PDF 排版基线

中文选用 CTeX 的 `ctexart`，英文选用 KOMA-Script 的 `scrartcl`。设计从文档类和 Quarto 内置模板出发，先记录原生结果，再添加有明确需求的覆盖；后续 Word 样式以这套成熟排版为参考。

公共 PDF 配置使用 XeLaTeX、A4 和 `geometry: margin=1in`，中英文四边页边距均为 25.4 mm。`indent: true` 让文档类管理段落缩进。中文字体方案由 CTeX 根据运行环境自动选择。字号、行距、标题、题注、浮动和页眉页脚使用类及 Quarto 的默认处理，不加载旧 `common.tex`、`zh.tex`、`title.tex`。

PDF 使用 authors-block 扩展补充机构、ORCID、贡献与通信信息；作者字体、日期和标题区仍由文档类处理。中文摘要带标题；英文通过 `classoption: [abstract=true]` 显示 Abstract 标题。原生结果和实测尺寸见 [PDF 基线记录](docs/PDF基线.md)。

## Word 中编辑章节

中英文 Word 的版心、字体和各类对象的样式见[Word 排版规范](docs/Word排版规范.md)。文末给出了桌面版 Word 的实测结果。

正文用 `#`、`##`、`###`，使用 `number-sections: true` 开启章节编号；参考文献保留 `.unnumbered`。

章节引用写为 `[@sec-标签]`（英文也可写 `@sec-标签`）。编号及引用统一由 Quarto 生成。增删或移动章节后，应修改 QMD 并重新渲染；Word 中的 Ctrl+A、F9 不会重新计算这些章节数字。Word 手工编辑不会写回 QMD，下一次渲染会覆盖生成文件。

Word 把“摘要”和 **Abstract** 与正文排在同一段，下一行回到版心左缘。摘要正文 11 pt，1.2 倍行距。填写 `keywords` 后，摘要下增加同行标签的关键词段。此版式也适用于无作者和多段摘要。

## 依赖与版本

已按 Quarto 1.11.9 / Pandoc 3.10 的本地环境设计。HTML、Word 不需要 R/Python；PDF 需要 XeLaTeX、ctex、KOMA-Script 和常见 LaTeX 宏包。PDF 西文与数学使用默认 Latin Modern 字体；中文字体方案由 CTeX 自动选择，本机 Windows 使用 Windows 字体方案。Word 字体由项目附带的中英文参考文档管理。

Word 参考文档、CSL 和作者扩展随模板一同安装。各来源的提交号和文件 SHA-256 见 `styles/manifest.json`。单独使用扩展时，可按清单中的 `authors_block.base_commit` 安装对应版本。

`styles/docx/document.xml` 安排首页顺序。作者扩展提供姓名、机构、链接和标记，Word 参考文档控制字体与段落。`compat.lua` 在 Quarto 完成编号后处理图表、公式及提示框。数据表保留可重复的原生表头，公式保留可编辑的 Word 数学对象，代码块采用 Quarto 默认的 `arrow` 语法配色。原生章节编号实验仍可由维护者显式运行 `scripts/finalize-docx.lua`。

Word 作者区采用“姓名 → ORCID → 机构数字 / † 上标 → 信封”，通信邮箱合并且不重复姓名。字号、图标比例、间距和元数据规则见 [作者区设计规范](docs/作者区设计规范.md)。该规范仅作用于 Word；HTML 和 PDF 的作者区保持各自实现。

## 检查效果

以下检查命令仅在模板仓库使用，新项目不携带测试和维护脚本。先运行 `quarto render --to all`，再运行 `python scripts/check-project.py`。检查脚本验证样式快照散列、Word 内部链接和作者图标、分图结构，以及 HTML 的图片和引用目标；安装 `pypdf` 后还会检查 PDF 文本、链接、A4 页面和字体嵌入。脚本检查不能代替页面目视检查。维护者可运行 `python tests/check_word_features.py` 检查编号开关、三级章节引用、自定义链接及不同提示框。`tests/check_word_fields.ps1` 保留为原生编号实验的检查脚本，当前默认跳过。

当前检查环境为 Windows / Microsoft Word / MiKTeX。当前 PDF 示例中英文各 5 页，本轮 Word 样张也各 5 页；页面数是示例结果，不是对新文档的限制。详细记录见 `docs/验证记录.md`。

## 维护

`scripts/init-project.ps1 -ProjectPath <新项目目录>` 是可选的 Git 配置辅助工具，不参与渲染，也不随模板复制；它只创建缺少的点文件，不覆盖已有配置。

`scripts/build-example-figures.py` 仅重建演示图片，需要 Pillow；渲染示例无需执行它。`scripts/sync-styles.py` 将已检查的相邻来源仓库更新为本地快照。正式更新应先提交当前项目，明确选择版本，再检查六种输出。手工发布供 `quarto use template` 安装的 ZIP 时，将 `_quarto.yml` 与 `.quartoignore` 放在归档根目录。

文献示例的原始来源是 [Knuth 1984](https://doi.org/10.1093/comjnl/27.2.97) 与 [Shannon 1948](https://doi.org/10.1002/j.1538-7305.1948.tb01338.x)。表格和曲线明确为合成数据。上游 DOCX 当前未提供独立许可证，保留其来源说明；CSL 与 ORCID 图标遵循各自的许可和品牌说明，不将整个仓库一概重许可。
