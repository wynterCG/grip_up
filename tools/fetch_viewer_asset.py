"""Inspect the creator's public CC0 animation viewer asset references."""
from pathlib import Path
import urllib.request
import re
work=Path(__file__).resolve().parents[1]/'builds'
url='https://quaternius.com/animviewer.html'
page=urllib.request.urlopen(url,timeout=30).read().decode('utf-8')
(work/'author_viewer.html').write_text(page,encoding='utf-8')
for line in page.splitlines():
    if '.glb' in line or '.gltf' in line or 'src=' in line or 'import ' in line:
        print(line[:600])
