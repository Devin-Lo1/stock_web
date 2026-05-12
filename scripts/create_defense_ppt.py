from pathlib import Path
from math import sin, cos, pi
import random

from PIL import Image, ImageDraw, ImageFilter
from pptx import Presentation
from pptx.chart.data import CategoryChartData
from pptx.dml.color import RGBColor
from pptx.enum.chart import XL_CHART_TYPE, XL_LEGEND_POSITION
from pptx.enum.shapes import MSO_AUTO_SHAPE_TYPE
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.util import Inches, Pt


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "ppt_assets"
OUT = Path.home() / "Desktop" / "基于DDPM的图像生成_毕设答辩.pptx"

W, H = 13.333, 7.5

NAVY = RGBColor(30, 58, 95)
BLUE = RGBColor(52, 152, 219)
PURPLE = RGBColor(118, 75, 162)
RED = RGBColor(231, 76, 60)
ORANGE = RGBColor(245, 158, 11)
GREEN = RGBColor(33, 150, 83)
BG = RGBColor(245, 247, 250)
DARK = RGBColor(31, 41, 55)
MUTED = RGBColor(99, 115, 129)
WHITE = RGBColor(255, 255, 255)
LIGHT_BLUE = RGBColor(232, 244, 252)
LIGHT_PURPLE = RGBColor(244, 238, 250)
LIGHT_RED = RGBColor(253, 237, 236)


def inch(v):
    return Inches(v)


def make_bg_assets():
    ASSETS.mkdir(exist_ok=True)
    title = ASSETS / "title_bg.png"
    if not title.exists():
        img = Image.new("RGB", (1920, 1080), (18, 36, 68))
        pix = img.load()
        for y in range(img.height):
            for x in range(img.width):
                t = (x / img.width * 0.75 + y / img.height * 0.25)
                r = int(18 + 30 * t)
                g = int(36 + 112 * t)
                b = int(68 + 135 * t)
                pix[x, y] = (r, g, b)
        d = ImageDraw.Draw(img, "RGBA")
        for x in range(0, 1920, 64):
            d.line([(x, 0), (x, 1080)], fill=(255, 255, 255, 22), width=1)
        for y in range(0, 1080, 64):
            d.line([(0, y), (1920, y)], fill=(255, 255, 255, 16), width=1)
        random.seed(7)
        pts = [(random.randint(0, 1920), random.randint(0, 1080)) for _ in range(130)]
        for x, y in pts:
            rr = random.randint(2, 5)
            d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=(173, 216, 255, 95))
        for i, (x1, y1) in enumerate(pts[:50]):
            for x2, y2 in pts[i + 1 : i + 5]:
                if (x1 - x2) ** 2 + (y1 - y2) ** 2 < 230**2:
                    d.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, 28), width=1)
        for cx, cy, rad, col in [
            (1570, 260, 260, (118, 75, 162, 120)),
            (1450, 820, 330, (52, 152, 219, 95)),
        ]:
            overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
            od = ImageDraw.Draw(overlay, "RGBA")
            od.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), fill=col)
            overlay = overlay.filter(ImageFilter.GaussianBlur(55))
            img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
        img.save(title)

    light = ASSETS / "light_bg.png"
    if not light.exists():
        img = Image.new("RGB", (1920, 1080), (247, 249, 252))
        d = ImageDraw.Draw(img, "RGBA")
        for x in range(0, 1920, 96):
            d.line([(x, 0), (x, 1080)], fill=(30, 58, 95, 10), width=1)
        for y in range(0, 1080, 96):
            d.line([(0, y), (1920, y)], fill=(30, 58, 95, 8), width=1)
        d.polygon([(1480, 0), (1920, 0), (1920, 1080), (1710, 1080)], fill=(232, 244, 252, 170))
        d.polygon([(0, 820), (520, 1080), (0, 1080)], fill=(244, 238, 250, 150))
        img.save(light)


def set_bg(slide, dark=False):
    path = ASSETS / ("title_bg.png" if dark else "light_bg.png")
    slide.shapes.add_picture(str(path), 0, 0, width=inch(W), height=inch(H))


def add_text(slide, text, x, y, w, h, size=18, color=DARK, bold=False, align=PP_ALIGN.LEFT, font="Microsoft YaHei"):
    box = slide.shapes.add_textbox(inch(x), inch(y), inch(w), inch(h))
    tf = box.text_frame
    tf.clear()
    tf.word_wrap = True
    tf.margin_left = inch(0.05)
    tf.margin_right = inch(0.05)
    tf.margin_top = inch(0.02)
    tf.margin_bottom = inch(0.02)
    p = tf.paragraphs[0]
    p.alignment = align
    run = p.add_run()
    run.text = text
    run.font.name = font
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = color
    return box


def add_title(slide, title, subtitle=None):
    add_text(slide, title, 0.55, 0.33, 10.9, 0.55, 28, NAVY, True)
    line = slide.shapes.add_shape(MSO_AUTO_SHAPE_TYPE.RECTANGLE, inch(0.58), inch(0.96), inch(1.25), inch(0.05))
    line.fill.solid()
    line.fill.fore_color.rgb = BLUE
    line.line.fill.background()
    if subtitle:
        add_text(slide, subtitle, 9.0, 0.42, 3.6, 0.35, 10.5, MUTED, False, PP_ALIGN.RIGHT)


def add_footer(slide, page):
    add_text(slide, f"{page:02d} / 12", 11.85, 7.03, 0.85, 0.22, 9, MUTED, False, PP_ALIGN.RIGHT)
    add_text(slide, "基于自适应秩DoRA的扩散模型微调优化", 0.63, 7.03, 4.8, 0.22, 9, MUTED)


def add_card(slide, x, y, w, h, title, body="", fill=WHITE, border=RGBColor(220, 228, 238), title_color=NAVY):
    shape = slide.shapes.add_shape(MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE, inch(x), inch(y), inch(w), inch(h))
    shape.fill.solid()
    shape.fill.fore_color.rgb = fill
    shape.line.color.rgb = border
    shape.line.width = Pt(1.0)
    add_text(slide, title, x + 0.16, y + 0.14, w - 0.32, 0.34, 15.5, title_color, True)
    if body:
        add_text(slide, body, x + 0.16, y + 0.58, w - 0.32, h - 0.72, 11.5, DARK)
    return shape


def add_pill(slide, text, x, y, w, color=BLUE):
    shape = slide.shapes.add_shape(MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE, inch(x), inch(y), inch(w), inch(0.38))
    shape.fill.solid()
    shape.fill.fore_color.rgb = color
    shape.line.fill.background()
    add_text(slide, text, x, y + 0.07, w, 0.2, 10.5, WHITE, True, PP_ALIGN.CENTER)
    return shape


def add_picture_contain(slide, path, x, y, w, h, border=None):
    p = Path(path)
    im = Image.open(p)
    iw, ih = im.size
    scale = min(w / iw, h / ih)
    ww, hh = iw * scale, ih * scale
    pic = slide.shapes.add_picture(str(p), inch(x + (w - ww) / 2), inch(y + (h - hh) / 2), width=inch(ww), height=inch(hh))
    if border:
        pic.line.color.rgb = border
        pic.line.width = Pt(1)
    return pic


def add_table(slide, rows, x, y, w, h, widths=None, header_fill=NAVY, highlight_row=None):
    table_shape = slide.shapes.add_table(len(rows), len(rows[0]), inch(x), inch(y), inch(w), inch(h))
    tbl = table_shape.table
    if widths:
        for i, cw in enumerate(widths):
            tbl.columns[i].width = inch(cw)
    for r, row in enumerate(rows):
        for c, val in enumerate(row):
            cell = tbl.cell(r, c)
            cell.text = str(val)
            cell.margin_left = inch(0.05)
            cell.margin_right = inch(0.05)
            cell.margin_top = inch(0.04)
            cell.margin_bottom = inch(0.04)
            fill = header_fill if r == 0 else (LIGHT_BLUE if highlight_row is not None and r == highlight_row else WHITE)
            cell.fill.solid()
            cell.fill.fore_color.rgb = fill
            cell.vertical_anchor = MSO_ANCHOR.MIDDLE
            for p in cell.text_frame.paragraphs:
                p.alignment = PP_ALIGN.CENTER
                for run in p.runs:
                    run.font.name = "Microsoft YaHei"
                    run.font.size = Pt(10.5 if r else 10)
                    run.font.bold = r == 0 or (highlight_row is not None and r == highlight_row)
                    run.font.color.rgb = WHITE if r == 0 else DARK
    return table_shape


def add_section_tag(slide, text):
    add_pill(slide, text, 0.63, 1.25, 1.65, NAVY)


def slide1(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(s, True)
    add_text(s, "基于DDPM的图像生成", 1.0, 1.7, 8.2, 0.7, 35, WHITE, True)
    add_text(s, "基于自适应秩DoRA的扩散模型微调优化研究", 1.0, 2.52, 8.8, 0.45, 20, RGBColor(210, 232, 255), True)
    add_text(s, "本科毕业设计答辩", 1.02, 3.22, 3.0, 0.3, 16, RGBColor(226, 239, 255), False)
    box = s.shapes.add_shape(MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE, inch(0.92), inch(5.75), inch(11.55), inch(0.9))
    box.fill.solid()
    box.fill.fore_color.rgb = RGBColor(14, 35, 62)
    box.fill.transparency = 18
    box.line.color.rgb = RGBColor(101, 174, 230)
    info = "答辩人：罗得文    学号：U202290026    专业班级：电信2205班    指导教师：刘澍    电子信息与通信学院    2026年4月"
    add_text(s, info, 1.08, 6.08, 11.2, 0.26, 13.5, WHITE, False, PP_ALIGN.CENTER)
    # Decorative network rings
    for i in range(6):
        cx, cy, r = 10.7 + 0.35 * sin(i), 2.35 + i * 0.25, 0.35 + i * 0.16
        shp = s.shapes.add_shape(MSO_AUTO_SHAPE_TYPE.OVAL, inch(cx - r), inch(cy - r), inch(r * 2), inch(r * 2))
        shp.fill.background()
        shp.line.color.rgb = RGBColor(162, 214, 255)
        shp.line.transparency = 25 + i * 8
        shp.line.width = Pt(1.2)
    return s


def slide2(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(s)
    add_title(s, "汇报结构", "10分钟答辩路线图")
    items = [
        ("01", "研究背景", "为什么需要高效微调？"),
        ("02", "问题分析", "固定秩DoRA为什么不够？"),
        ("03", "方法设计", "SVD能量谱 + 自适应秩分配"),
        ("04", "实验验证", "参数、显存、质量指标对比"),
        ("05", "总结展望", "贡献与后续方向"),
    ]
    x_num, x_text = 1.15, 2.35
    y0, gap = 1.42, 1.02
    line = s.shapes.add_shape(MSO_AUTO_SHAPE_TYPE.RECTANGLE, inch(1.78), inch(1.68), inch(0.05), inch(4.35))
    line.fill.solid()
    line.fill.fore_color.rgb = BLUE
    line.line.fill.background()
    for idx, (num, title, desc) in enumerate(items):
        y = y0 + idx * gap
        add_text(s, num, x_num, y, 0.9, 0.44, 22, BLUE if idx != 2 else PURPLE, True, PP_ALIGN.CENTER, "Arial")
        add_card(s, x_text, y - 0.02, 8.8, 0.72, title, desc, WHITE, RGBColor(224, 232, 241))
    add_text(s, "问题 → 方法 → 结果 → 总结", 8.65, 6.25, 3.3, 0.36, 16, PURPLE, True, PP_ALIGN.RIGHT)
    add_footer(s, 2)


def slide3(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(s)
    add_title(s, "研究背景：扩散模型效果强，但微调成本高")
    add_section_tag(s, "为什么做")
    stages = [("GAN/VAE", "早期生成模型"), ("DDPM", "逐步加噪/去噪"), ("Stable Diffusion", "潜在空间高效生成"), ("PEFT", "低成本领域适配")]
    for i, (a, b) in enumerate(stages):
        x = 0.75 + i * 2.2
        add_pill(s, a, x, 2.05, 1.45, BLUE if i < 3 else PURPLE)
        add_text(s, b, x - 0.08, 2.52, 1.65, 0.28, 10.5, MUTED, False, PP_ALIGN.CENTER)
        if i < 3:
            add_text(s, "→", x + 1.62, 2.08, 0.35, 0.25, 18, BLUE, True, PP_ALIGN.CENTER)
    cards = [
        ("U-Net参数规模大", "Stable Diffusion核心U-Net约8.6亿参数"),
        ("全参数微调昂贵", "显存、算力和优化器状态开销高"),
        ("小数据易遗忘", "领域数据有限时可能破坏通用能力"),
        ("细节纹理难学", "PCB、锂电池、连接器等高频结构要求高"),
    ]
    for i, (t, b) in enumerate(cards):
        add_card(s, 7.7, 1.55 + i * 0.95, 4.55, 0.74, t, b, WHITE, RGBColor(224, 232, 241), RED if i < 2 else NAVY)
    banner = s.shapes.add_shape(MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE, inch(0.82), inch(6.25), inch(11.7), inch(0.62))
    banner.fill.solid()
    banner.fill.fore_color.rgb = NAVY
    banner.line.fill.background()
    add_text(s, "目标：在有限参数和显存预算下，提高扩散模型在复杂科技图像上的细节生成能力。", 1.0, 6.43, 11.35, 0.22, 14.5, WHITE, True, PP_ALIGN.CENTER)
    add_footer(s, 3)


def slide4(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(s)
    add_title(s, "技术基础：从扩散生成到参数高效微调")
    content = [
        ("DDPM / Stable Diffusion", "正向：逐步加入高斯噪声\n反向：U-Net预测噪声并去除\nStable Diffusion在潜在空间执行去噪", LIGHT_BLUE),
        ("LoRA", "冻结原模型权重\n低秩矩阵近似权重更新\nΔW = BA\n优点：参数少\n局限：幅度与方向耦合", WHITE),
        ("DoRA", "权重更新分解为幅度和方向\n幅度向量独立更新\n方向矩阵低秩更新\n优点：表达能力更强\n局限：仍常采用全局固定秩", LIGHT_PURPLE),
    ]
    for i, (t, b, fill) in enumerate(content):
        x = 0.7 + i * 4.08
        add_card(s, x, 1.45, 3.55, 4.25, t, b, fill, RGBColor(219, 228, 239), NAVY if i != 2 else PURPLE)
        # simple diagrams
        if i == 0:
            for j, lab in enumerate(["x0", "xt", "x0"]):
                add_pill(s, lab, x + 0.55 + j * 0.78, 4.62, 0.55, BLUE if j != 1 else RED)
                if j < 2:
                    add_text(s, "→", x + 1.12 + j * 0.78, 4.66, 0.28, 0.2, 13, NAVY, True, PP_ALIGN.CENTER)
        elif i == 1:
            add_text(s, "A", x + 0.82, 4.6, 0.35, 0.25, 18, BLUE, True, PP_ALIGN.CENTER)
            add_text(s, "×", x + 1.32, 4.6, 0.25, 0.25, 16, MUTED, True, PP_ALIGN.CENTER)
            add_text(s, "B", x + 1.78, 4.6, 0.35, 0.25, 18, BLUE, True, PP_ALIGN.CENTER)
        else:
            add_text(s, "Magnitude", x + 0.45, 4.54, 1.1, 0.25, 11.5, PURPLE, True, PP_ALIGN.CENTER)
            add_text(s, "+", x + 1.6, 4.55, 0.25, 0.25, 14, MUTED, True, PP_ALIGN.CENTER)
            add_text(s, "Direction", x + 1.9, 4.54, 1.0, 0.25, 11.5, PURPLE, True, PP_ALIGN.CENTER)
    add_text(s, "DoRA解决了“怎么表达”，但没有解决“每一层该分多少秩”。", 1.1, 6.35, 11.1, 0.35, 18, RED, True, PP_ALIGN.CENTER)
    add_footer(s, 4)


def slide5(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(s)
    add_title(s, "核心问题：U-Net各层需求不同，固定秩会错配资源")
    add_section_tag(s, "问题定位")
    add_text(s, "不同注意力层的信息复杂度不同，不应使用同一个秩。", 2.5, 1.28, 8.8, 0.35, 18, NAVY, True, PP_ALIGN.CENTER)
    add_picture_contain(s, ASSETS / "image5.png", 3.95, 2.05, 5.45, 2.72, RGBColor(220, 228, 238))
    add_card(s, 0.75, 2.0, 2.85, 1.35, "固定低秩 R4", "深层复杂特征被截断\n细节纹理欠拟合", LIGHT_RED, RGBColor(244, 199, 195), RED)
    add_card(s, 9.85, 2.0, 2.85, 1.35, "固定高秩 R16", "浅层获得过多自由度\n参数冗余、显存浪费", RGBColor(255, 247, 237), RGBColor(250, 214, 165), ORANGE)
    add_card(s, 0.75, 4.05, 2.85, 1.35, "浅层/简单层", "提取轮廓和背景\n秩需求较低", WHITE, RGBColor(224, 232, 241), NAVY)
    add_card(s, 9.85, 4.05, 2.85, 1.35, "深层/关键层", "负责复杂语义与细纹理\n秩需求较高", LIGHT_PURPLE, RGBColor(221, 205, 237), PURPLE)
    add_text(s, "需要一种层级感知的自适应秩分配机制", 3.25, 5.82, 6.9, 0.38, 18, PURPLE, True, PP_ALIGN.CENTER)
    add_footer(s, 5)


def slide6(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(s)
    add_title(s, "本文方法：基于SVD能量谱的自适应秩DoRA")
    add_text(s, "利用SVD估计每层真实秩需求，在总参数预算不变的前提下重新分配DoRA秩。", 0.92, 1.25, 11.5, 0.35, 15.5, NAVY, True, PP_ALIGN.CENTER)
    steps = [
        ("1", "导向模型预热", "较高冗余秩短步微调\n获得各层权重更新先验"),
        ("2", "SVD能量分析", "对每层增量矩阵分解\n计算累积能量谱"),
        ("3", "本征秩估计", "寻找达到能量阈值\n所需的最小秩"),
        ("4", "预算守恒分配", "缩放、截断与余量反哺\n保持平均秩约束"),
    ]
    for i, (n, t, b) in enumerate(steps):
        x = 0.75 + i * 3.12
        add_card(s, x, 2.0, 2.55, 2.0, f"{n}. {t}", b, LIGHT_BLUE if i < 3 else LIGHT_PURPLE, RGBColor(218, 228, 240), NAVY if i < 3 else PURPLE)
        if i < 3:
            add_text(s, "→", x + 2.62, 2.78, 0.38, 0.28, 20, BLUE, True, PP_ALIGN.CENTER)
    formula = "W = UΣVᵀ\nE(r)=Σᵢ₌₁ʳ σᵢ² / Σᵢ σᵢ²\nrᵢ = argmin{r | Eᵢ(r) ≥ θ}"
    add_card(s, 0.85, 4.55, 4.85, 1.25, "关键公式", formula, WHITE, RGBColor(224, 232, 241), PURPLE)
    add_picture_contain(s, ASSETS / "image9.png", 6.25, 4.42, 5.45, 1.45, RGBColor(224, 232, 241))
    add_text(s, "不是增加参数，而是重新分配参数。", 3.3, 6.35, 6.9, 0.38, 20, RED, True, PP_ALIGN.CENTER)
    add_footer(s, 6)


def slide7(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(s)
    add_title(s, "算法设计：预算守恒的自适应秩分配")
    code_box = s.shapes.add_shape(MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE, inch(0.8), inch(1.35), inch(6.15), inch(4.9))
    code_box.fill.solid()
    code_box.fill.fore_color.rgb = RGBColor(22, 31, 45)
    code_box.line.color.rgb = RGBColor(70, 98, 128)
    code = (
        "Input: ΔW_i, 总预算 B, 能量阈值 θ\n"
        "For each layer i:\n"
        "    SVD(ΔW_i) → σ_i\n"
        "    计算能量谱 E_i(r)\n"
        "    得到理论秩 r_i*\n\n"
        "Normalize: r_i ← scale(r_i*, B)\n"
        "Clip:      r_i ← clamp(r_i, r_min, r_max)\n"
        "Feedback:  余量重新分配给未触及边界的层\n"
        "Output: {r_i}"
    )
    add_text(s, code, 1.05, 1.65, 5.62, 4.25, 13.2, RGBColor(232, 244, 252), False, PP_ALIGN.LEFT, "Consolas")
    points = [
        ("层级感知", "不同层分配不同秩"),
        ("预算守恒", "总参数量受控，便于公平对比"),
        ("极值约束", "防止单层参数垄断，保持U-Net拓扑连通性"),
    ]
    for i, (t, b) in enumerate(points):
        add_card(s, 7.45, 1.45 + i * 1.4, 4.55, 1.05, t, b, WHITE if i != 2 else LIGHT_PURPLE, RGBColor(224, 232, 241), PURPLE if i == 2 else NAVY)
    add_text(s, "冗余层  →  关键层", 7.75, 5.78, 3.6, 0.32, 18, PURPLE, True, PP_ALIGN.CENTER)
    add_text(s, "核心思想：让参数流向最需要表达能力的层。", 1.15, 6.55, 10.95, 0.3, 16, NAVY, True, PP_ALIGN.CENTER)
    add_footer(s, 7)


def slide8(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(s)
    add_title(s, "实验设置：复杂科技图像生成任务")
    blocks = [
        ("数据集", "约1000张高分辨率工业级图像\nPCB走线、智能手机主板、裸露锂电池、镀金连接器\n目标：测试复杂纹理与拓扑一致性"),
        ("基础模型", "Stable Diffusion v1.5\n训练分辨率：512×512\n微调目标：U-Net注意力投影层 q/k/v/out"),
        ("对比方法", "Fixed Rank 4 DoRA：低资源基线\nFixed Rank 16 DoRA：高容量基线\nAdaptive Avg8 DoRA：本文方法"),
        ("评价指标", "参数量、峰值显存、单步训练耗时\nFID\nCLIP Directional Similarity\n定性视觉结果"),
    ]
    coords = [(0.75, 1.35), (6.85, 1.35), (0.75, 4.05), (6.85, 4.05)]
    for i, ((t, b), (x, y)) in enumerate(zip(blocks, coords)):
        add_card(s, x, y, 5.6, 2.25, t, b, LIGHT_BLUE if i in (0, 3) else WHITE, RGBColor(224, 232, 241), PURPLE if i == 2 else NAVY)
    add_pill(s, "Adaptive Avg8 DoRA", 8.45, 5.25, 2.2, PURPLE)
    add_footer(s, 8)


def slide9(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(s)
    add_title(s, "结果一：接近R4的显存，接近R16的表达能力")
    rows = [
        ["方法", "可训练参数量", "峰值显存", "单步耗时"],
        ["Fixed Rank 16 DoRA", "3.29M", "7.2GB", "320ms"],
        ["Fixed Rank 4 DoRA", "0.90M", "4.8GB", "265ms"],
        ["Adaptive Avg8 DoRA", "1.69M", "5.1GB", "278ms"],
    ]
    add_table(s, rows, 0.7, 1.45, 6.05, 1.72, [2.15, 1.35, 1.25, 1.25], highlight_row=3)
    data = CategoryChartData()
    data.categories = ["R16", "R4", "Adaptive"]
    data.add_series("参数量(M)", (3.29, 0.90, 1.69))
    data.add_series("显存(GB)", (7.2, 4.8, 5.1))
    chart = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, inch(0.75), inch(3.55), inch(6.0), inch(2.45), data).chart
    chart.has_legend = True
    chart.legend.position = XL_LEGEND_POSITION.BOTTOM
    chart.chart_title.has_text_frame = True
    chart.chart_title.text_frame.text = "资源开销对比"
    for series in chart.series:
        series.format.fill.solid()
    chart.series[0].format.fill.fore_color.rgb = PURPLE
    chart.series[1].format.fill.fore_color.rgb = BLUE
    metrics = [
        ("-48.5%", "参数量比R16减少"),
        ("5.1GB", "峰值显存"),
        ("-13.1%", "单步耗时比R16降低"),
    ]
    for i, (num, lab) in enumerate(metrics):
        add_card(s, 7.45, 1.55 + i * 1.45, 4.45, 1.02, num, lab, LIGHT_PURPLE if i == 0 else WHITE, RGBColor(224, 232, 241), PURPLE if i == 0 else NAVY)
        add_text(s, num, 7.7, 1.75 + i * 1.45, 1.9, 0.35, 24, PURPLE if i == 0 else BLUE, True)
    add_text(s, "Adaptive Avg8在资源开销上接近低秩模型，但保留更强表达能力。", 1.25, 6.6, 10.8, 0.28, 15.5, NAVY, True, PP_ALIGN.CENTER)
    add_footer(s, 9)


def slide10(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(s)
    add_title(s, "结果二：低参数量下保持接近高秩模型的生成质量")
    rows = [
        ["方法", "参数量", "FID ↓", "CLIP Dir. Sim ↑"],
        ["R16 DoRA", "3.29M", "162.08", "0.3024"],
        ["R4 DoRA", "0.90M", "176.77", "0.2962"],
        ["Adaptive Avg8", "1.69M", "163.31", "0.2961"],
    ]
    add_table(s, rows, 0.65, 1.35, 5.15, 1.65, [1.75, 1.05, 1.05, 1.3], highlight_row=3)
    data = CategoryChartData()
    data.categories = ["R16", "R4", "Adaptive"]
    data.add_series("FID", (162.08, 176.77, 163.31))
    chart = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, inch(0.75), inch(3.35), inch(5.05), inch(2.35), data).chart
    chart.has_legend = False
    chart.chart_title.has_text_frame = True
    chart.chart_title.text_frame.text = "FID越低越好"
    chart.series[0].format.fill.solid()
    chart.series[0].format.fill.fore_color.rgb = BLUE
    imgs = [("R4", ASSETS / "image15.png", "细节模糊 / 纹理粘连"),
            ("Adaptive", ASSETS / "image17.png", "结构清晰 / 材质稳定"),
            ("R16", ASSETS / "image16.png", "细节较强 / 参数量大")]
    for i, (lab, path, desc) in enumerate(imgs):
        x = 6.1 + i * 2.22
        add_card(s, x, 1.35, 2.05, 3.58, lab, "", LIGHT_PURPLE if lab == "Adaptive" else WHITE, PURPLE if lab == "Adaptive" else RGBColor(224, 232, 241), PURPLE if lab == "Adaptive" else NAVY)
        add_picture_contain(s, path, x + 0.12, 1.92, 1.8, 1.95)
        add_text(s, desc, x + 0.14, 4.25, 1.75, 0.36, 10.5, DARK, False, PP_ALIGN.CENTER)
    add_text(s, "Adaptive Avg8的FID仅比R16高1.23，但参数量约为R16的一半。", 0.95, 6.55, 11.5, 0.3, 15.5, PURPLE, True, PP_ALIGN.CENTER)
    add_footer(s, 10)


def slide11(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(s)
    add_title(s, "消融分析：极值约束保证整体拓扑稳定")
    add_card(s, 0.75, 1.35, 5.45, 4.25, "无极值约束", "部分层秩过高，出现参数垄断\n局部金属反光等细节仍可能保留\n但全局几何结构混乱\n背景扭曲，电子元件位置不合理", LIGHT_RED, RGBColor(244, 199, 195), RED)
    add_card(s, 7.1, 1.35, 5.45, 4.25, "加入极值约束", "避免单层过度占用预算\n保留浅层基础结构表达能力\n维持U-Net信息流拓扑连通性\n生成图像结构更稳定", LIGHT_BLUE, RGBColor(196, 224, 244), NAVY)
    add_text(s, "×", 5.98, 2.3, 0.38, 0.35, 25, RED, True, PP_ALIGN.CENTER)
    add_text(s, "✓", 6.92, 2.3, 0.38, 0.35, 25, GREEN, True, PP_ALIGN.CENTER)
    add_text(s, "无约束分配 → 参数垄断 → 拓扑崩塌", 1.25, 5.95, 4.6, 0.28, 13.5, RED, True, PP_ALIGN.CENTER)
    add_text(s, "约束分配 → 均衡流动 → 稳定生成", 7.55, 5.95, 4.55, 0.28, 13.5, NAVY, True, PP_ALIGN.CENTER)
    add_text(s, "自适应不是完全自由分配，而是在预算守恒和秩边界下进行可控优化。", 1.2, 6.55, 10.9, 0.28, 15.5, PURPLE, True, PP_ALIGN.CENTER)
    add_footer(s, 11)


def slide12(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(s)
    add_title(s, "总结与展望")
    contrib = [
        ("理论分析", "揭示Stable Diffusion U-Net注意力层存在明显秩需求差异"),
        ("方法设计", "提出基于SVD能量谱与DoRA的自适应秩分配机制"),
        ("实验验证", "Adaptive Avg8以1.69M参数、5.1GB显存取得接近R16的生成质量"),
    ]
    for i, (t, b) in enumerate(contrib):
        add_card(s, 0.75 + i * 4.1, 1.45, 3.55, 1.65, t, b, LIGHT_BLUE if i != 1 else LIGHT_PURPLE, RGBColor(224, 232, 241), PURPLE if i == 1 else NAVY)
    add_text(s, "未来展望", 0.9, 3.78, 2.2, 0.3, 18, NAVY, True)
    futures = ["在线动态秩调整机制", "扩展到更多模型结构和数据集", "结合人类偏好或多模态评价指标"]
    for i, f in enumerate(futures):
        x = 1.15 + i * 3.85
        shp = s.shapes.add_shape(MSO_AUTO_SHAPE_TYPE.OVAL, inch(x), inch(4.45), inch(0.42), inch(0.42))
        shp.fill.solid()
        shp.fill.fore_color.rgb = BLUE if i != 1 else PURPLE
        shp.line.fill.background()
        add_text(s, str(i + 1), x, 4.54, 0.42, 0.16, 9.5, WHITE, True, PP_ALIGN.CENTER, "Arial")
        add_text(s, f, x - 0.55, 5.0, 1.7, 0.55, 12.5, DARK, False, PP_ALIGN.CENTER)
        if i < 2:
            add_text(s, "→", x + 2.0, 4.47, 0.5, 0.28, 18, BLUE, True, PP_ALIGN.CENTER)
    add_text(s, "感谢各位老师指导，恳请批评指正！", 2.4, 6.35, 8.5, 0.5, 25, NAVY, True, PP_ALIGN.CENTER)
    add_footer(s, 12)


def main():
    make_bg_assets()
    prs = Presentation()
    prs.slide_width = inch(W)
    prs.slide_height = inch(H)
    for fn in [slide1, slide2, slide3, slide4, slide5, slide6, slide7, slide8, slide9, slide10, slide11, slide12]:
        fn(prs)
    prs.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
