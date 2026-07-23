#!/bin/zsh
# Regenerates the brand logo badges in QRX/Assets.xcassets/BrandLogos/.
#
# Glyphs: simple-icons (CC0 icon data; glyph shapes are the brands' trademarks,
# used to indicate where a code points — see the in-app trademark notice).
# Google's multicolor G comes from Wikimedia Commons (official artwork).
# Badge style: 512px brand-color rounded square (r=115) + white glyph,
# matching the standard "find us on X" signage look.
#
# Run from this directory: ./gen_brand_logos.sh
set -euo pipefail
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
WORK=$(mktemp -d)
OUT="../QRX/Assets.xcassets/BrandLogos"
cd "$WORK"

typeset -A COLORS
COLORS=(facebook "#0866FF" x "#000000" tiktok "#000000" youtube "#FF0000" \
        whatsapp "#25D366" spotify "#1DB954" linkedin "#0A66C2")

for slug in facebook x tiktok youtube whatsapp spotify linkedin; do
  curl -sf "https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/$slug.svg" -o "$slug.raw.svg"
  path=$(sed -n 's/.*<path d="\([^"]*\)".*/\1/p' "$slug.raw.svg")
  cat > "$slug.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
<rect width="512" height="512" rx="115" fill="${COLORS[$slug]}"/>
<g transform="translate(96,96) scale(13.3333)"><path d="$path" fill="#FFFFFF"/></g></svg>
SVG
done

# Instagram: official gradient background
curl -sf "https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/instagram.svg" -o instagram.raw.svg
igpath=$(sed -n 's/.*<path d="\([^"]*\)".*/\1/p' instagram.raw.svg)
cat > instagram.svg <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
<defs><radialGradient id="ig" cx="0.3" cy="1.07" r="1.5">
<stop offset="0" stop-color="#FDF497"/><stop offset="0.05" stop-color="#FDF497"/>
<stop offset="0.45" stop-color="#FD5949"/><stop offset="0.6" stop-color="#D6249F"/>
<stop offset="0.9" stop-color="#285AEB"/></radialGradient></defs>
<rect width="512" height="512" rx="115" fill="url(#ig)"/>
<g transform="translate(96,96) scale(13.3333)"><path d="$igpath" fill="#FFFFFF"/></g></svg>
SVG

# Google: multicolor G on white
curl -sf 'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg' -o google.raw.svg
inner=$(python3 -c "s=open('google.raw.svg').read(); print(s[s.index('>')+1:s.rindex('</svg>')])")
cat > google.svg <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
<rect width="512" height="512" rx="115" fill="#FFFFFF"/>
<g transform="translate(96,96) scale(13.3333)">$inner</g></svg>
SVG

for slug in facebook google instagram linkedin spotify tiktok whatsapp x youtube; do
  printf '<!doctype html><body style="margin:0"><img src="%s.svg" style="width:512px;height:512px;display:block"></body>' "$slug" > view.html
  "$CHROME" --headless --disable-gpu --screenshot="$slug.png" --window-size=512,512 --hide-scrollbars "file://$WORK/view.html" 2>/dev/null
  cp "$slug.png" "$OLDPWD/$OUT/brand.$slug.imageset/$slug.png"
  echo "wrote brand.$slug"
done
