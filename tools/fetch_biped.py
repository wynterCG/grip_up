"""Acquire the author's free CC0 mannequin; never submits a payment."""
from pathlib import Path
import http.cookiejar
import urllib.request
import re
import json
import urllib.parse
import html
import zipfile

work=Path(__file__).resolve().parents[1]/'builds'
base='https://quaternius.itch.io/universal-animation-library'
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
def get(url,data=None):
    return opener.open(urllib.request.Request(url,data=data,headers={'User-Agent':'Mozilla/5.0','Referer':base+'/purchase'}),timeout=60)

page=get(base+'/purchase').read().decode('utf-8')
(work/'mannequin_purchase.html').write_text(page,encoding='utf-8')
csrf=re.search(r'<meta name="csrf_token" value="([^"]+)"',page).group(1)
# Public "No thanks, just take me to the downloads" action, price is zero.
reply=json.loads(get(base+'/download_url',urllib.parse.urlencode({'csrf_token':csrf}).encode()).read())
assert urllib.parse.urlparse(reply['url']).hostname=='quaternius.itch.io'
download_page=get(reply['url']).read().decode('utf-8')
(work/'mannequin_download.html').write_text(download_page,encoding='utf-8')
free_upload=re.search(r'data-upload_id="(\d+)"[^>]*class="button download_btn"',download_page).group(1)
assert 'Universal Animation Library[Standard].zip' in download_page
csrf2=re.search(r'<meta name="csrf_token" value="([^"]+)"',download_page).group(1)
result=json.loads(get(base+'/file/'+free_upload+'?source=game_download&as_props=1',urllib.parse.urlencode({'csrf_token':csrf2}).encode()).read())
assert result['url'].startswith('https://')
archive=work/'quaternius_universal_animation_standard.zip'
with get(result['url']) as response, archive.open('wb') as handle:
    while chunk:=response.read(1024*1024): handle.write(chunk)
with zipfile.ZipFile(archive) as pack:
    for item in pack.infolist():
        if item.filename.lower().endswith(('.glb','.txt','.md','.png')):
            print(item.filename,item.file_size)
print('Free author archive downloaded:',archive.stat().st_size,'bytes')
