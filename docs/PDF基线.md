# PDF 排版基线

建立日期：2026-11-16。先采用成熟 LaTeX 文档类及 Quarto 内置模板，记录原生结果，再针对实际需求添加必要调整。后续 Word 的字号层级、段落与图表样式以此为参考，分别适配各格式的排版机制。

## 文档类选择

| 语言 | 文档类 | 选择依据 |
|---|---|---|
| 中文 | `ctexart` | CTeX 的中文文章类，提供中文字体方案、标点处理、标题和段落规则，适合通用中文科研文章与研究报告 |
| 英文 | `scrartcl` | KOMA-Script 的文章类，有完整的版心计算和标题体系，也是 Quarto 默认的 PDF 文档类 |

依据：[CTeX 官方包说明](https://ctan.org/pkg/ctex)、[scrartcl 官方包说明](https://ctan.org/pkg/scrartcl)、[Quarto PDF 文档类说明](https://quarto.org/docs/output-formats/pdf-basics.html#document-class)。这是通用科研写作基线；投稿指定的期刊或会议文档类可另行选择。

## 最小配置

`_quarto.yml` 的 PDF 部分：

```yaml
format:
  pdf:
    pdf-engine: xelatex
    papersize: a4
    geometry: margin=1in
    indent: true
```

`indent: true` 让 Quarto 保留文档类的段落缩进和间距处理。若省略，Quarto 的默认模板会改为段间留白的方式；它不是“首行统一缩进某个手写长度”。[Quarto 配置说明](https://quarto.org/docs/reference/formats/pdf.html#layout)

中文单篇配置：

```yaml
format:
  pdf:
    documentclass: ctexart
```

英文单篇配置：

```yaml
format:
  pdf:
    documentclass: scrartcl
    classoption: [abstract=true]
```

中文不显式指定 `fontset`，由 CTeX 自动选择字体方案。本机 Windows 自动使用 `windows`，macOS 使用 `mac`，其他系统通常使用 `fandol`；跨系统的字体及分页可能不同。标题、作者、语言、日期、摘要和文献文件由单篇设置，CSL 和章节编号由项目统一设置。

## 默认行为的来源

这里的“原生”指 Quarto 内置 LaTeX 模板与所选文档类。Quarto 为 Markdown 内容提供的表格、引用、代码、图像及语言支持继续运行。

- 中文生成的类选项为 `chinese-hans, a4paper`；通过 `geometry: margin=1in` 将四边页边距设为 25.4 mm，A4 正文区约为 159.2 × 246.2 mm。
- 英文生成的类选项包括 `english, a4paper, abstract=true, DIV=11, numbers=noendperiod`。后两项是 Quarto 自动提供的 KOMA 配置，未在项目中重复设置。
- 字体、标题字号及段落规则来自文档类和默认字体支持。中文正文为宋体，标题按 CTeX 使用黑体；西文、代码和数学采用 Latin Modern 系列。
- 中文一级标题居中，普通页有文档类默认页眉；英文标题靠左、使用无衬线粗体。摘要、题注和页码均保留各自的原生处理。
- 默认作者区使用姓名及 `\and` 排列，只显示姓名。机构、ORCID、同等贡献、通信作者与邮箱仍保存在 QMD 元数据中，原生基线未展示这些字段；当前模板通过 `authors-block` 排印。
- 中文摘要显示“摘要”标题；`scrartcl` 默认摘要不显示 Abstract 标题。当前英文单篇显式设置 `abstract=true`，显示 Abstract 标题。
- 链接使用 Quarto 默认的蓝色。表格和题注使用内置转换；图片按默认浮动机制排列，可能与源码出现的位置不同。

## 实测基线

以下是增加中文 1 英寸页边距之前的原生基线测量，通过生成的 LaTeX 输出寄存器并结合 PDF 字体信息确认。当前中文正文区已调整为约 159.2 × 246.2 mm；表中原始版心尺寸留作对照，字号和段落规则未覆盖。

| 项目 | 中文 | 英文 |
|---|---|---|
| 正文字号 | CTeX 五号，PDF 中 10.5 pt | KOMA 默认 11 pt 档，PDF 中约 10.91 pt |
| `\textwidth` | 345 TeX pt | 434.55125 TeX pt |
| `\textheight` | 598 TeX pt | 623.00027 TeX pt |
| `\parindent` | 21.07874 TeX pt，约两个汉字宽 | 10.95 TeX pt，约 1 em |
| `\parskip` | `0pt plus 1pt` | `0pt plus 1pt` |
| `\baselineskip` | 16.44145 TeX pt | 13.6 TeX pt |
| `\baselinestretch` | 1.3，来自 CTeX | 1 |

TeX pt 为 1/72.27 英寸，PDF 的点为 1/72 英寸，因此 PDF 中的测量值与 TeX 数值会略有差别。首段是否缩进仍由具体文档类和上下文处理。

测试环境：Quarto 1.11.9、Pandoc 3.10、XeTeX / MiKTeX 26.5；本机安装的 `ctexart` 为 2.5.10，`scrartcl` 为 3.49.2。版本记录用于说明本次结果，并不代表已锁定所有工具链和字体。

## 已停用的覆盖

项目不再加载 `styles/latex/common.tex`、`styles/latex/zh.tex` 和 `styles/latex/title.tex`。这些文件及 ORCID 素材保留供对照，均不参与当前 PDF。

撤下的配置包括统一 11 pt 字号、Termes/Heros/Consolas 字体、额外 CJK 字体指定、旧中文自定页边距与 `linestretch: 1.2`、中文标题重定义、统一题注样式、全局 `fig-pos: H`、表格缩小及预留空间、强制孤行控制、自定义链接色和作者区。默认摘要、作者与字体出现变化是建立基线的预期结果。

Word 样式在本次基线工作中保持原状。当时的 HTML 基线使用 `cosmo`；当前两份示例均在各自 QMD 中选择 `litera`。后续优先讨论作者与摘要所需功能，再评估图表和正文的阅读体验；每项覆盖都应有明确用途和实际渲染依据。

## 重建与检查

```powershell
quarto render template-zh.qmd --to pdf
quarto render template-en.qmd --to pdf
python scripts/check-project.py
```

调试实际 LaTeX 时可临时使用 `-M keep-tex:true`。不要手改生成的 `.tex`；基线变更写回 QMD 或项目配置，并同步此记录。

## 文档类与中文页边距定稿（2026-11-16）

已确定英文继续使用 `scrartcl`，中文保留 `ctexart` 并采用 `geometry: margin=1in`；已应用到正式中文示例。中文正文宽度由约 121 mm 增加到 159.2 mm，示例从 5 页变为 4 页，字号与行距保留类默认值。25.4 mm 是本项目通用科研文档的页边距选择，不是中文论文统一规范。ElegantPaper 仅保留为历史比较，einfart 已排除。

建议稿及同尺度预览位于 `output/ctexart-margins/`，尺寸测量、历史页边距与 ElegantPaper 的适配范围记录于该目录的 README。

## 作者扩展（2026-11-17）

PDF filters 按 quarto、authors-block 的顺序运行，读取规范化作者数据。扩展通过公开 LaTeX hook 设置增强后的 author 内容；保留文档类 maketitle、日期与摘要。图标按当前字体 H 的高度缩放，说明默认使用类的 small。颜色遵循项目 colorlinks: false。只支持 XeLaTeX 的 ctexart / scrartcl；旧 styles/latex/title.tex 仍停用。
