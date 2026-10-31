from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math, os, subprocess, sys

N = 1024
SS = 2
M = N * SS
CREAM = (255, 252, 240, 255)

def L(v):
    return int(v * SS)

def radial(size,center,r_in,r_out,c_in,c_out):
    im=Image.new("RGB",size); px=im.load(); cx,cy=center
    for y in range(size[1]):
        for x in range(size[0]):
            t=min(1,max(0,(math.hypot(x-cx,y-cy)-r_in)/(r_out-r_in)))
            px[x,y]=tuple(int(c_in[i]+(c_out[i]-c_in[i])*t) for i in range(3))
    return im

def squircle_mask():
    m=Image.new("L",(M*2,M*2),0); ImageDraw.Draw(m).rounded_rectangle([0,0,M*2-1,M*2-1],radius=int(M*2*0.2237),fill=255)
    return m.resize((M,M),Image.LANCZOS)

def swirl(layer,cx,cy,rx,ry,turns=1.25):
    d=ImageDraw.Draw(layer); steps=700; pts=[]
    for k in range(steps+1):
        t=k/steps; ang=t*turns*2*math.pi+0.9; r=0.10+0.78*t
        pts.append((cx+math.cos(ang)*rx*r, cy+math.sin(ang)*ry*r))
    for i in range(len(pts)):
        t=i/steps; w=L(5)+L(13)*math.sin(math.pi*min(1,t*0.95+0.04))
        d.ellipse([pts[i][0]-w/2,pts[i][1]-w/2,pts[i][0]+w/2,pts[i][1]+w/2],fill=(255,255,250,240))

def artwork():
    cx=M/2
    if False:
        base=Image.new("RGBA",(M,M),(18,34,26,255))
        bg=radial((256,256),(128,110),10,190,(36,70,52),(12,24,18)).resize((M,M),Image.BICUBIC).convert("RGBA")
        im=bg
    elif False:
        bg=radial((256,256),(128,96),10,200,(104,176,124),(40,100,66)).resize((M,M),Image.BICUBIC).convert("RGBA"); im=bg
    else:
        bg=radial((256,256),(128,92),10,205,(66,148,96),(18,64,42)).resize((M,M),Image.BICUBIC).convert("RGBA"); im=bg
    sc=0.80 if False else 1.0
    top=L(510) if True else L(540)
    R=int(L(312)*sc); BW=int(L(204)*sc); H=int(L(398)*sc); rimh=int(L(128)*sc); bot=top+H
    if False:
        rg=Image.new("RGBA",(M,M),(0,0,0,0)); rd=ImageDraw.Draw(rg)
        rd.ellipse([L(96),L(96),M-L(96),M-L(96)],outline=(70,170,104,255),width=L(30))
        rd.arc([L(96),L(96),M-L(96),M-L(96)],start=-90,end=150,fill=(170,236,160,255),width=L(30))
        im=Image.alpha_composite(im,rg)
    disc=Image.new("RGBA",(M,M),(0,0,0,0)); ImageDraw.Draw(disc).ellipse([cx-int(L(300)*sc),bot-L(4),cx+int(L(300)*sc),bot+L(60)],fill=(255,255,255,30))
    im=Image.alpha_composite(im,disc)
    cm=Image.new("L",(M,M),0)
    ImageDraw.Draw(cm).polygon([(cx-R-L(40),top-L(120)),(cx+R+L(40),top-L(120)),(cx+BW,bot),(cx-BW,bot)],fill=255)
    cm=cm.filter(ImageFilter.GaussianBlur(L(30))).point(lambda v:255 if v>128 else 0).filter(ImageFilter.GaussianBlur(L(1)))
    ImageDraw.Draw(cm).rectangle([0,0,M,top],fill=0)
    im.paste(Image.new("RGBA",(M,M),CREAM),(0,0),cm)
    # soft second tone on the right for volume, kept subtle
    tone=Image.new("RGBA",(M,M),(0,0,0,0)); td=ImageDraw.Draw(tone)
    td.polygon([(cx+int(R*0.42),top),(cx+R+L(40),top),(cx+BW+L(10),bot+L(10)),(cx+int(BW*0.55),bot+L(10))],fill=(222,214,190,255))
    tm=ImageChops.multiply(tone.split()[3],cm); tone.putalpha(tm.point(lambda v:int(v*0.55)))
    im=Image.alpha_composite(im,tone)
    d=ImageDraw.Draw(im,"RGBA")
    # slim cream rim, large green surface
    rim=Image.new("RGBA",(M,M),(0,0,0,0)); rd=ImageDraw.Draw(rim)
    rd.ellipse([cx-R-L(4),top-rimh/2,cx+R+L(4),top+rimh/2],fill=CREAM); im=Image.alpha_composite(im,rim)
    ins=int(L(13)*sc)
    box=[cx-R+ins,top-rimh/2+int(L(9)*sc),cx+R-ins,top+rimh/2-int(L(6)*sc)]
    tw,th=int(box[2]-box[0]),int(box[3]-box[1])
    surf=radial((tw,th),(tw*0.40,th*0.38),4,tw*0.60,(156,208,92),(62,128,60)).convert("RGBA")
    sm=Image.new("L",(tw,th),0); ImageDraw.Draw(sm).ellipse([0,0,tw-1,th-1],fill=255)
    im.paste(surf,(int(box[0]),int(box[1])),sm)
    sw=Image.new("RGBA",(M,M),(0,0,0,0)); swirl(sw,(box[0]+box[2])/2,(box[1]+box[3])/2,tw*0.44,th*0.40)
    sm2=Image.new("L",(M,M),0); ImageDraw.Draw(sm2).ellipse([box[0]+L(6),box[1]+L(5),box[2]-L(6),box[3]-L(5)],fill=255)
    sw.putalpha(ImageChops.multiply(sw.split()[3],sm2))
    im=Image.alpha_composite(im,sw.filter(ImageFilter.GaussianBlur(L(0.6))))
    st=Image.new("RGBA",(M,M),(0,0,0,0)); sd=ImageDraw.Draw(st); base_y=top-rimh/2-int(L(30)*sc); hh=int(L(150)*sc); w=int(L(26)*sc)
    for dx,ph in ((-int(L(62)*sc),0.0),(int(L(62)*sc),3.14159)):
        pts=[(cx+dx+math.sin((k/90)*math.pi*2+ph)*int(L(20)*sc),base_y-(k/90)*hh) for k in range(91)]
        for i in range(len(pts)):
            sd.ellipse([pts[i][0]-w/2,pts[i][1]-w/2,pts[i][0]+w/2,pts[i][1]+w/2],fill=CREAM)
    im=Image.alpha_composite(im,st)
    out=Image.new("RGBA",(M,M),(0,0,0,0)); out.paste(im,(0,0),squircle_mask())
    return out.resize((N,N),Image.LANCZOS)


def finish(art):
    inner = 824
    icon = art.resize((inner, inner), Image.LANCZOS)
    canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 70), ((N - inner) // 2, (N - inner) // 2 + 10), icon.split()[3])
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(12)))
    canvas.alpha_composite(icon, ((N - inner) // 2, (N - inner) // 2))
    return canvas

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.join(here, "..")
    master = finish(artwork())
    iconset = os.path.join(root, "Resources", "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)
    for base in (16, 32, 128, 256, 512):
        master.resize((base, base), Image.LANCZOS).save(os.path.join(iconset, f"icon_{base}x{base}.png"))
        master.resize((base * 2, base * 2), Image.LANCZOS).save(os.path.join(iconset, f"icon_{base}x{base}@2x.png"))
    subprocess.check_call(["iconutil", "-c", "icns", iconset, "-o", os.path.join(root, "Resources", "AppIcon.icns")])
    master.save(os.path.join(root, "docs", "images", "icon.png"))
