# Règle l'import des textures pour le mobile : compression VRAM (ETC2/ASTC), mipmaps,
# cartes de normales compressées comme telles. Usage : python3 tools/fix_imports.py
import glob, re
for f in glob.glob('assets/textures/*.import') + glob.glob('assets/characters/*.jpg.import'):
    s = open(f).read()
    s = re.sub(r'compress/mode=\d', 'compress/mode=2', s)
    s = re.sub(r'mipmaps/generate=\w+', 'mipmaps/generate=true', s)
    s = re.sub(r'detect_3d/compress_to=\d', 'detect_3d/compress_to=0', s)
    if 'normal' in f.lower():
        s = re.sub(r'compress/normal_map=\d', 'compress/normal_map=1', s)
    open(f, 'w').write(s)
