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
    bg=radial((256,256),(128,92),10,205,(66,148,96),(18,64,42)).resize((M,M),Image.BICUBIC).convert("RGBA")
    im=bg; cx=M/2
    k=1.12
    top=L(468); R=int(L(262)*k); H=int(L(240)*k); rimh=int(L(104)*k); bot=top+H
    layer=Image.new("RGBA",(M,M),(0,0,0,0)); d=ImageDraw.Draw(layer)
    sw=int(L(372)*k); sy=bot+int(L(8)*k)
    d.ellipse([cx-sw,sy-int(L(48)*k),cx+sw,sy+int(L(62)*k)],fill=(236,228,206,255))
    d.ellipse([cx-sw+L(14),sy-int(L(40)*k),cx+sw-L(14),sy+int(L(50)*k)],fill=CREAM)
    d.ellipse([cx-int(sw*0.60),sy-int(L(22)*k),cx+int(sw*0.60),sy+int(L(36)*k)],fill=(240,233,212,255))
    hx=cx+R-int(L(10)*k); hy=top+int(L(96)*k)
    d.ellipse([hx-int(L(92)*k),hy-int(L(74)*k),hx+int(L(92)*k),hy+int(L(74)*k)],outline=CREAM,width=int(L(34)*k))
    im=Image.alpha_composite(im,layer)
    # cup body (rounded bowl profile)
    cm=Image.new("L",(M,M),0); cd=ImageDraw.Draw(cm); pts=[]
    for i in range(61):
        t=i/60; w=R*(1-0.62*t**1.6); pts.append((cx+w,top+H*t))
    poly=pts+[(2*cx-x,y) for x,y in reversed(pts)]
    cd.polygon(poly,fill=255)
    cm=cm.filter(ImageFilter.GaussianBlur(L(22))).point(lambda v:255 if v>128 else 0).filter(ImageFilter.GaussianBlur(L(1)))
    ImageDraw.Draw(cm).rectangle([0,0,M,top],fill=0)
    sh=Image.new("RGBA",(M,M),(0,0,0,0)); ImageDraw.Draw(sh).ellipse([cx-int(L(150)*k),bot-L(6),cx+int(L(150)*k),bot+int(L(40)*k)],fill=(0,0,0,50))
    im=Image.alpha_composite(im,sh.filter(ImageFilter.GaussianBlur(L(8))))
    im.paste(Image.new("RGBA",(M,M),CREAM),(0,0),cm)
    tone=Image.new("RGBA",(M,M),(0,0,0,0)); ImageDraw.Draw(tone).polygon([(cx+int(R*0.50),top),(cx+R+L(40),top),(cx+R+L(40),bot+L(20)),(cx+int(R*0.50),bot+L(20))],fill=(226,218,194,255))
    tone.putalpha(ImageChops.multiply(tone.split()[3],cm).point(lambda v:int(v*0.5)))
    im=Image.alpha_composite(im,tone)
    rim=Image.new("RGBA",(M,M),(0,0,0,0)); ImageDraw.Draw(rim).ellipse([cx-R-L(4),top-rimh/2,cx+R+L(4),top+rimh/2],fill=CREAM); im=Image.alpha_composite(im,rim)
    ins=int(L(13)*k); box=[cx-R+ins,top-rimh/2+int(L(9)*k),cx+R-ins,top+rimh/2-int(L(6)*k)]
    tw,th=int(box[2]-box[0]),int(box[3]-box[1])
    surf=radial((tw,th),(tw*0.40,th*0.38),4,tw*0.60,(156,208,92),(62,128,60)).convert("RGBA")
    sm=Image.new("L",(tw,th),0); ImageDraw.Draw(sm).ellipse([0,0,tw-1,th-1],fill=255)
    im.paste(surf,(int(box[0]),int(box[1])),sm)
    sl=Image.new("RGBA",(M,M),(0,0,0,0)); swirl(sl,(box[0]+box[2])/2,(box[1]+box[3])/2,tw*0.44,th*0.40)
    m2=Image.new("L",(M,M),0); ImageDraw.Draw(m2).ellipse([box[0]+L(6),box[1]+L(5),box[2]-L(6),box[3]-L(5)],fill=255)
    sl.putalpha(ImageChops.multiply(sl.split()[3],m2)); im=Image.alpha_composite(im,sl.filter(ImageFilter.GaussianBlur(L(0.6))))
    st=Image.new("RGBA",(M,M),(0,0,0,0)); sd=ImageDraw.Draw(st); by=top-rimh/2-int(L(28)*k); hh=int(L(130)*k); w=int(L(24)*k)
    for dx,ph in ((-int(L(56)*k),0.0),(int(L(56)*k),3.14159)):
        pts=[(cx+dx+math.sin((q/90)*math.pi*2+ph)*int(L(18)*k),by-(q/90)*hh) for q in range(91)]
        for p in pts: sd.ellipse([p[0]-w/2,p[1]-w/2,p[0]+w/2,p[1]+w/2],fill=CREAM)
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
