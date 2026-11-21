# 样式与版本

- `docx/`：中英文 Word 参考文档和必要的 Quarto 兼容代码。
- `csl/`：本地 IEEE CSL，保留原文件作者和 CC BY-SA 3.0 声明。
- `latex/`：保留旧 PDF 共享宏、作者标题块及素材，当前原生基线不加载这些覆盖。中文 ctexart、英文 scrartcl 在单篇文档中选择。
- `html/`：保留旧屏幕阅读样式，当前不加载；HTML 使用 Quarto 的 `cosmo` 主题。
- `manifest.json`：来源、基线 commit、开发版本和 SHA-256。标为工作树快照的文件包含未发布的本地修改，不能把基线 commit 当作修改后的发布版本。

Word 样式由相邻 `pandoc_docx_template` 仓库中的 `scripts/build_quarto_references.py` 生成，原始普通版模板保持不变。正文中英文分别使用首行缩进与段间距；其他样式以清晰的层级、紧凑题注和三线表为主。

Word 作者区采用本项目的独立规范：“姓名 → ORCID → 机构数字及 † 上标 → 通信信封”。作者 12 pt，机构与说明 10.5 pt，居中、1.15 倍行距。ORCID 直径 0.75 em，保留绿色；信封为黑色矢量轮廓，保持行内大小。机构每项一段，同等贡献使用 †，通信邮箱合并为一段、按作者顺序排列，不重复姓名。日期和摘要继续排在作者信息之后。作者元数据和渲染用法见 [使用说明](../docs/使用说明.md)。详细设计记录保留在模板仓库。

Word 使用带 PNG 回退的 SVG。扩展从参考文档的 Author 和 Affiliation 样式读取有效字号，沿继承链推算图标、间距和上标。需要单独覆盖行内比例的基准时可填写 `authors-block.docx.author-size`、`note-size`。素材来源见扩展的 `assets/README.md`。

PDF 采用 Quarto 内置 LaTeX 模板与文档类排版，由 authors-block 补充机构、ORCID、同等贡献和通信信息。`latex/title.tex`、`latex/common.tex`、`latex/zh.tex` 及 ORCID 素材作为旧设计保留但不启用。PDF 基线的测量与开发记录保留在模板仓库。HTML 使用 Quarto 原生作者区。

`docx/document.xml` 基于 Pandoc 3.10 的 DOCX 正文模板，接收作者说明，并依次排日期、摘要与关键词。`front-matter.lua` 为摘要首段、续段、关键词及行内标签绑定样式。升级 Pandoc 时用 `quarto pandoc -D docx` 对照模板。

`docx/compat.lua` 在 Quarto 核心过滤器之后处理直接格式、分图及提示框。`layout.lua` 把题注和注限制在对象宽度内，保留可独立分页的数据表，将已编号公式和编号放在各自的位置。Word 代码默认使用 Quarto 的 `arrow` 配色。自定义配色 `docx/research.theme` 作为备选保存在样式快照中。章节编号沿用 Quarto，常规渲染在 Pandoc 写出 DOCX 前完成。

维护者在两个来源仓库检查修改后，运行 `python scripts/sync-styles.py` 更新快照，再重新渲染受影响的格式并运行检查。普通使用者无需运行这个脚本。发布时记录真实发布 commit/tag；已经创建的项目不会自动更新。

仅固定样式文件不能保证不同电脑上的分页完全相同。归档应保留最终 PDF、Quarto/Pandoc/TeX 版本与字体信息；需要更强复现性时固定工具链环境。
