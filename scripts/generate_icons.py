#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil

def resize_image(src_path, dst_path, width, height):
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    # 1. Tentar com sips (nativo do macOS)
    if shutil.which("sips"):
        cmd = ["sips", "-z", str(height), str(width), src_path, "--out", dst_path]
        res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if res.returncode == 0:
            return True

    # 2. Tentar com PIL
    try:
        from PIL import Image
        img = Image.open(src_path).convert("RGBA")
        img.resize((width, height), Image.Resampling.LANCZOS).save(dst_path, "PNG")
        return True
    except Exception as e:
        pass

    # 3. Fallback cópia
    shutil.copyfile(src_path, dst_path)
    return True

def generate_icons(icon_path="assets/icon.png"):
    if not os.path.exists(icon_path):
        print(f"Erro: {icon_path} não encontrado!")
        return

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
        for folder, (w, h) in sizes.items():
            out_file = os.path.join(android_res, folder, "ic_launcher.png")
            resize_image(icon_path, out_file, w, h)
            print(f"Gerado Android {out_file}")

    # ── 2. iOS Icons ──
    ios_iconset = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    if os.path.exists("ios"):
        os.makedirs(ios_iconset, exist_ok=True)
        # Ícone 1024x1024
        resize_image(icon_path, os.path.join(ios_iconset, "Icon-App-1024x1024@1x.png"), 1024, 1024)

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
        for name, (w, h) in ios_sizes.items():
            resize_image(icon_path, os.path.join(ios_iconset, name), w, h)

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
        print("Gerado iOS AppIcon.appiconset!")

    # ── 3. Web Icons ──
    os.makedirs("web/icons", exist_ok=True)
    resize_image(icon_path, "web/favicon.png", 16, 16)
    resize_image(icon_path, "web/icons/Icon-192.png", 192, 192)
    resize_image(icon_path, "web/icons/Icon-512.png", 512, 512)
    resize_image(icon_path, "web/icons/Icon-maskable-192.png", 192, 192)
    resize_image(icon_path, "web/icons/Icon-maskable-512.png", 512, 512)
    print("Gerado Web/PWA icons!")

if __name__ == "__main__":
    generate_icons()
