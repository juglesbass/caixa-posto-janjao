#!/usr/bin/env python3
import os
import sys
from PIL import Image

def generate_icons(icon_path="assets/icon.png"):
    if not os.path.exists(icon_path):
        print(f"Erro: {icon_path} não encontrado!")
        return

    img = Image.open(icon_path).convert("RGBA")
    
    # ── 1. Android Icons ──
    android_res = "android/app/src/main/res"
    if os.path.exists("android"):
        sizes = {
            "mipmap-mdpi": (48, 48),
            "mipmap-hdpi": (72, 72),
            "mipmap-xhdpi": (96, 96),
            "mipmap-xxhdpi": (144, 144),
            "mipmap-xxxhdpi": (192, 192),
        }
        for folder, size in sizes.items():
            dir_path = os.path.join(android_res, folder)
            os.makedirs(dir_path, exist_ok=True)
            out_file = os.path.join(dir_path, "ic_launcher.png")
            img.resize(size, Image.Resampling.LANCZOS).save(out_file, "PNG")
            print(f"Gerado Android {out_file} ({size[0]}x{size[1]})")

    # ── 2. iOS Icons ──
    ios_iconset = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    if os.path.exists("ios"):
        os.makedirs(ios_iconset, exist_ok=True)
        # Ícone 1024x1024 principal
        img_1024 = img.resize((1024, 1024), Image.Resampling.LANCZOS)
        img_1024.save(os.path.join(ios_iconset, "Icon-App-1024x1024@1x.png"), "PNG")
        
        # Tamanhos legados
        ios_sizes = {
            "Icon-App-20x20@1x.png": (20, 20),
            "Icon-App-20x20@2x.png": (40, 40),
            "Icon-App-20x20@3x.png": (60, 60),
            "Icon-App-29x29@1x.png": (29, 29),
            "Icon-App-29x29@2x.png": (58, 58),
            "Icon-App-29x29@3x.png": (87, 87),
            "Icon-App-40x40@1x.png": (40, 40),
            "Icon-App-40x40@2x.png": (80, 80),
            "Icon-App-40x40@3x.png": (120, 120),
            "Icon-App-60x60@2x.png": (120, 120),
            "Icon-App-60x60@3x.png": (180, 180),
            "Icon-App-76x76@1x.png": (76, 76),
            "Icon-App-76x76@2x.png": (152, 152),
            "Icon-App-83.5x83.5@2x.png": (167, 167),
        }
        for name, size in ios_sizes.items():
            out_file = os.path.join(ios_iconset, name)
            img.resize(size, Image.Resampling.LANCZOS).save(out_file, "PNG")

        # Contents.json padrão do Xcode
        contents_json = """{
  "images" : [
    {
      "size" : "20x20",
      "idiom" : "iphone",
      "filename" : "Icon-App-20x20@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "20x20",
      "idiom" : "iphone",
      "filename" : "Icon-App-20x20@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "Icon-App-29x29@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "Icon-App-29x29@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "Icon-App-29x29@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "40x40",
      "idiom" : "iphone",
      "filename" : "Icon-App-40x40@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "40x40",
      "idiom" : "iphone",
      "filename" : "Icon-App-40x40@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "60x60",
      "idiom" : "iphone",
      "filename" : "Icon-App-60x60@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "60x60",
      "idiom" : "iphone",
      "filename" : "Icon-App-60x60@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "20x20",
      "idiom" : "ipad",
      "filename" : "Icon-App-20x20@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "20x20",
      "idiom" : "ipad",
      "filename" : "Icon-App-20x20@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "29x29",
      "idiom" : "ipad",
      "filename" : "Icon-App-29x29@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "29x29",
      "idiom" : "ipad",
      "filename" : "Icon-App-29x29@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "40x40",
      "idiom" : "ipad",
      "filename" : "Icon-App-40x40@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "40x40",
      "idiom" : "ipad",
      "filename" : "Icon-App-40x40@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "76x76",
      "idiom" : "ipad",
      "filename" : "Icon-App-76x76@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "76x76",
      "idiom" : "ipad",
      "filename" : "Icon-App-76x76@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "83.5x83.5",
      "idiom" : "ipad",
      "filename" : "Icon-App-83.5x83.5@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "1024x1024",
      "idiom" : "ios-marketing",
      "filename" : "Icon-App-1024x1024@1x.png",
      "scale" : "1x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}"""
        with open(os.path.join(ios_iconset, "Contents.json"), "w") as f:
            f.write(contents_json)
        print("Gerado iOS AppIcon.appiconset com sucesso!")

    # ── 3. Web Icons ──
    os.makedirs("web/icons", exist_ok=True)
    img.resize((16, 16), Image.Resampling.LANCZOS).save("web/favicon.png", "PNG")
    img.resize((192, 192), Image.Resampling.LANCZOS).save("web/icons/Icon-192.png", "PNG")
    img.resize((512, 512), Image.Resampling.LANCZOS).save("web/icons/Icon-512.png", "PNG")
    img.resize((192, 192), Image.Resampling.LANCZOS).save("web/icons/Icon-maskable-192.png", "PNG")
    img.resize((512, 512), Image.Resampling.LANCZOS).save("web/icons/Icon-maskable-512.png", "PNG")
    print("Gerado Web/PWA icons com sucesso!")

if __name__ == "__main__":
    generate_icons()
