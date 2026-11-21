"""Generate the bundled synthetic illustrations; requires Pillow, not needed to render QMD."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"figures"
OUT.mkdir(exist_ok=True)
FONT=Path("C:/Windows/Fonts")
def font(size,bold=False):
    candidates=[FONT/("arialbd.ttf" if bold else "arial.ttf"),Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")]
    for p in candidates:
        if p.exists(): return ImageFont.truetype(str(p),size)
    raise RuntimeError("Install Arial or DejaVu Sans before rebuilding example figures.")
INK="#293642"; BLUE="#386e95"; GOLD="#ad702b"; GRID="#dce3e8"
def centered(d,xy,text,size=30,bold=False,fill=INK):
    d.text(xy,text,font=font(size,bold),fill=fill,anchor="mm")

im=Image.new("RGB",(1500,300),"white"); d=ImageDraw.Draw(im)
for rect,label,sub in [((10,80,360,220),"Source","Text · data · references"),((474,80,836,220),"Quarto","Labels · citations · styles")]:
    d.rounded_rectangle(rect,12,fill="#f1f5f7",outline=BLUE,width=3)
    centered(d,((rect[0]+rect[2])/2,130),label,38,True)
    centered(d,((rect[0]+rect[2])/2,177),sub,29)
for y,label in [(50,"HTML"),(150,"Word"),(250,"PDF")]:
    d.rounded_rectangle((1110,y-35,1470,y+35),10,fill="#f1f5f7",outline=BLUE,width=3)
    centered(d,(1290,y),label,32,True)
    d.line([(836,150),(960,150),(960,y),(1090,y)],fill=BLUE,width=4)
    d.polygon([(1105,y),(1087,y-8),(1087,y+8)],fill=BLUE)
d.line((360,150,453,150),fill=BLUE,width=4);d.polygon([(469,150),(451,142),(451,158)],fill=BLUE)
im.save(OUT/"workflow.png")

# Each 800 px panel occupies about 199 pt in the two-column Word figure.
# A 32 px font therefore prints at about 8 pt.
CHART_FONT = 32
PLOT_LEFT, PLOT_RIGHT = 96, 736
PLOT_TOP, PLOT_BOTTOM = 76, 408


def chart(ylabel, ticks):
    image = Image.new("RGB", (800, 520), "white")
    draw = ImageDraw.Draw(image)

    def y_position(value):
        fraction = (value - ticks[0]) / (ticks[-1] - ticks[0])
        return PLOT_BOTTOM - fraction * (PLOT_BOTTOM - PLOT_TOP)

    for value in ticks:
        y = y_position(value)
        draw.line((PLOT_LEFT, y, PLOT_RIGHT, y), fill=GRID, width=2)
        draw.text((PLOT_LEFT - 12, y), str(value), font=font(CHART_FONT), fill=INK, anchor="rm")
    draw.line([(PLOT_LEFT, PLOT_TOP), (PLOT_LEFT, PLOT_BOTTOM), (PLOT_RIGHT, PLOT_BOTTOM)],
              fill=INK, width=3)
    draw.text((PLOT_LEFT, 31), ylabel, font=font(34, True), fill=INK, anchor="lm")
    return image, draw, y_position


im, d, accuracy_y = chart("Accuracy (%)", range(60, 101, 10))
sample_counts = [100, 200, 400, 600, 800]
max_count = max(sample_counts)


def sample_x(count):
    return PLOT_LEFT + (PLOT_RIGHT - PLOT_LEFT) * count / max_count


for count in [0, *sample_counts]:
    x = sample_x(count)
    d.line((x, PLOT_BOTTOM, x, PLOT_BOTTOM + 6), fill=INK, width=2)
    centered(d, (x, 441), str(count), CHART_FONT)

series = [
    ("Method A", BLUE, [68, 74, 80, 84, 86.2]),
    ("Method B", GOLD, [71, 78, 85, 88, 89.1]),
]
for legend_x, (label, color, values) in zip((354, 568), series):
    points = [(sample_x(count), accuracy_y(value)) for count, value in zip(sample_counts, values)]
    d.line(points, fill=color, width=5)
    for x, y in points:
        d.ellipse((x - 6, y - 6, x + 6, y + 6), fill=color)
    d.line((legend_x, 31, legend_x + 32, 31), fill=color, width=5)
    d.text((legend_x + 41, 31), label, font=font(CHART_FONT), fill=INK, anchor="lm")
centered(d, ((PLOT_LEFT + PLOT_RIGHT) / 2, 489), "Sample count", CHART_FONT)
im.save(OUT / "accuracy.png")

im, d, latency_y = chart("Latency (ms)", range(0, 41, 10))
for x, value, color, label in [(256, 24, BLUE, "Method A"), (576, 31, GOLD, "Method B")]:
    y = latency_y(value)
    d.rectangle((x - 75, y, x + 75, PLOT_BOTTOM - 1), fill=color)
    centered(d, (x, y - 27), str(value), CHART_FONT, bold=True)
    centered(d, (x, 441), label, CHART_FONT)
centered(d, ((PLOT_LEFT + PLOT_RIGHT) / 2, 489), "Synthetic example data", CHART_FONT)
im.save(OUT / "latency.png")
print("Generated workflow.png, accuracy.png, latency.png (synthetic data).")
