import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

os.makedirs("assets/textures", exist_ok=True)

# 1. Wood texture (planks / rustic javanese wood)
def create_wood_texture():
    w, h = 512, 512
    img = Image.new("RGB", (w, h), (85, 52, 32))
    draw = ImageDraw.Draw(img)
    
    # Draw wood fibers / grain
    for y in range(h):
        for x in range(w):
            grain = int(math.sin(x * 0.05 + math.sin(y * 0.01) * 5) * 20 + math.cos(y * 0.2) * 10)
            noise = random.randint(-8, 8)
            r = max(0, min(255, 75 + grain + noise))
            g = max(0, min(255, 45 + grain//2 + noise))
            b = max(0, min(255, 25 + grain//3 + noise))
            img.putpixel((x, y), (r, g, b))
            
    # Add dark plank lines
    for py in [128, 256, 384]:
        draw.line([(0, py), (w, py)], fill=(30, 18, 10), width=4)
        draw.line([(0, py+1), (w, py+1)], fill=(20, 10, 5), width=2)
        
    img = img.filter(ImageFilter.SMOOTH)
    img.save("assets/textures/wood_albedo.png")
    print("Generated wood_albedo.png")

# 2. Mud / Earth texture (desa malam tanah becek)
def create_mud_texture():
    w, h = 512, 512
    img = Image.new("RGB", (w, h), (45, 38, 28))
    for y in range(h):
        for x in range(w):
            n1 = math.sin(x * 0.08) * math.cos(y * 0.08) * 25
            n2 = random.randint(-15, 15)
            r = max(0, min(255, int(42 + n1 + n2)))
            g = max(0, min(255, int(35 + n1*0.8 + n2*0.8)))
            b = max(0, min(255, int(26 + n1*0.6 + n2*0.6)))
            img.putpixel((x, y), (r, g, b))
    img = img.filter(ImageFilter.GaussianBlur(1))
    img.save("assets/textures/mud_albedo.png")
    print("Generated mud_albedo.png")

# 3. Stone / Cobblestone texture (sumur & nisan kuburan)
def create_stone_texture():
    w, h = 512, 512
    img = Image.new("RGB", (w, h), (70, 72, 75))
    for y in range(h):
        for x in range(w):
            grain = int(math.sin(x * 0.15) * 15 + math.cos(y * 0.15) * 15)
            noise = random.randint(-20, 20)
            val = max(0, min(255, 80 + grain + noise))
            # subtle moss greenish tint
            img.putpixel((x, y), (val - 5, val + (5 if noise > 5 else 0), val - 5))
    img = img.filter(ImageFilter.SMOOTH_MORE)
    img.save("assets/textures/stone_albedo.png")
    print("Generated stone_albedo.png")

# 4. Keranda cloth texture (kain hijau tua bercorak misterius)
def create_cloth_texture():
    w, h = 512, 512
    img = Image.new("RGB", (w, h), (18, 50, 25))
    draw = ImageDraw.Draw(img)
    for y in range(h):
        for x in range(w):
            weave = (x % 4 - 2) * 5 + (y % 4 - 2) * 5
            noise = random.randint(-6, 6)
            r = max(0, min(255, 14 + weave + noise))
            g = max(0, min(255, 48 + weave + noise))
            b = max(0, min(255, 24 + weave + noise))
            img.putpixel((x, y), (r, g, b))
    # Golden embroidery pattern
    for i in range(16, w, 64):
        draw.line([(i, 0), (i, h)], fill=(160, 130, 40), width=2)
    for j in range(16, h, 64):
        draw.line([(0, j), (w, j)], fill=(160, 130, 40), width=2)
    img.save("assets/textures/cloth_green.png")
    print("Generated cloth_green.png")

# 5. Bamboo texture (batang bambu)
def create_bamboo_texture():
    w, h = 256, 512
    img = Image.new("RGB", (w, h), (40, 65, 30))
    draw = ImageDraw.Draw(img)
    for y in range(h):
        for x in range(w):
            stripe = int(math.sin(x * 0.3) * 15)
            noise = random.randint(-5, 5)
            r = max(0, min(255, 45 + stripe + noise))
            g = max(0, min(255, 75 + stripe + noise))
            b = max(0, min(255, 25 + stripe + noise))
            img.putpixel((x, y), (r, g, b))
    # Bamboo nodes (ruas)
    for ny in [80, 190, 310, 430]:
        draw.line([(0, ny), (w, ny)], fill=(30, 40, 15), width=6)
        draw.line([(0, ny-2), (w, ny-2)], fill=(80, 100, 40), width=2)
    img.save("assets/textures/bamboo_albedo.png")
    print("Generated bamboo_albedo.png")

# 6. Horror vignette mask
def create_vignette_mask():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cx, cy = w / 2, h / 2
    max_dist = math.sqrt(cx**2 + cy**2)
    for y in range(h):
        for x in range(w):
            dist = math.hypot(x - cx, y - cy)
            norm = dist / max_dist
            alpha = 0
            if norm > 0.4:
                alpha = int(((norm - 0.4) / 0.6) ** 2 * 255)
            img.putpixel((x, y), (0, 0, 0, min(255, alpha)))
    img.save("assets/textures/vignette_mask.png")
    print("Generated vignette_mask.png")

# 7. Reticle / Crosshair dot
def create_crosshair():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # White dot with soft translucent outline
    draw.ellipse([(13, 13), (19, 19)], fill=(255, 255, 255, 180), outline=(0, 0, 0, 120))
    img.save("assets/textures/crosshair.png")
    print("Generated crosshair.png")

if __name__ == "__main__":
    create_wood_texture()
    create_mud_texture()
    create_stone_texture()
    create_cloth_texture()
    create_bamboo_texture()
    create_vignette_mask()
    create_crosshair()
    print("All textures created successfully!")
