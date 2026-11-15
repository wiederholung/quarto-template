"""Generate the bundled synthetic illustrations; requires Pillow, not needed to render QMD."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

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
for rect,label,sub in [((20,80,350,220),"Source","Text · data · references"),((490,80,820,220),"Quarto","Labels · citations · styles")]:
    d.rounded_rectangle(rect,12,fill="#f1f5f7",outline=BLUE,width=3)
    centered(d,((rect[0]+rect[2])/2,130),label,38,True)
    centered(d,((rect[0]+rect[2])/2,177),sub,24)
for y,label in [(50,"HTML"),(150,"Word"),(250,"PDF")]:
    d.rounded_rectangle((1110,y-35,1470,y+35),10,fill="#f1f5f7",outline=BLUE,width=3)
    centered(d,(1290,y),label,32,True)
    d.line([(820,150),(960,150),(960,y),(1090,y)],fill=BLUE,width=4)
    d.polygon([(1105,y),(1087,y-8),(1087,y+8)],fill=BLUE)
d.line((350,150,470,150),fill=BLUE,width=4);d.polygon([(485,150),(467,142),(467,158)],fill=BLUE)
im.save(OUT/"workflow.png")

def chart(ylabel):
    im=Image.new("RGB",(800,520),"white");d=ImageDraw.Draw(im)
    d.line([(110,40),(110,420),(750,420)],fill=INK,width=3)
    d.text((110,10),ylabel,font=font(27,True),fill=INK)
    return im,d
im,d=chart("Accuracy (%)")
for v in range(60,101,10):
    y=420-(v-60)/40*350
    d.line((110,y,750,y),fill=GRID,width=2)
    d.text((90,y),str(v),font=font(25),fill=INK,anchor="rm")
xs=[100,200,400,600,800]
for i,x in enumerate(xs): centered(d,(140+i*145,450),str(x),24)
for vals,col in [([68,74,80,84,86.2],BLUE),([71,78,85,88,89.1],GOLD)]:
    points=[(140+i*145,420-(v-60)/40*350) for i,v in enumerate(vals)]
    d.line(points,fill=col,width=5)
    for x,y in points:d.ellipse((x-6,y-6,x+6,y+6),fill=col)
d.line((475,35,520,35),fill=BLUE,width=5);d.text((530,35),"Method A",font=font(23),fill=INK,anchor="lm")
d.line((475,70,520,70),fill=GOLD,width=5);d.text((530,70),"Method B",font=font(23),fill=INK,anchor="lm")
centered(d,(430,495),"Sample count",27)
im.save(OUT/"accuracy.png")
im,d=chart("Latency (ms)")
for v in range(0,41,10):
    y=420-v/40*350; d.line((110,y,750,y),fill=GRID,width=2)
    d.text((90,y),str(v),font=font(25),fill=INK,anchor="rm")
for x,val,col,label in [(300,24,BLUE,"Method A"),(590,31,GOLD,"Method B")]:
    y=420-val/40*350; d.rectangle((x-75,y,x+75,419),fill=col)
    centered(d,(x,y-25),str(val),29,True);centered(d,(x,455),label,27)
centered(d,(430,495),"Synthetic example data",24)
im.save(OUT/"latency.png")
print("Generated workflow.png, accuracy.png, latency.png (synthetic data).")
