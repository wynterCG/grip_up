"""Render and inspect the embedded Windows test UI from an empty temporary cwd."""
from pathlib import Path
import subprocess
import tempfile
import re
import json
import hashlib
root = Path(__file__).resolve().parents[1]
exe = root/'builds/GripUp-v1.2-tests.exe'
out = root/'docs/validation/v12/export'
out.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='grip_up_export_qa_') as folder:
    run = subprocess.run([str(exe),'--screen','0','--quit-after','1000','--','--locomotion-tests-ui','--locomotion-tests-smoke','--evidence='+out.as_posix()],
                         cwd=folder,capture_output=True,timeout=90)
text = (run.stdout+run.stderr).decode('utf-8',errors='replace').replace('\r','').rstrip()+'\n'
(out/'windows_ui_output.txt').write_text(text,encoding='utf-8')
footer = re.search(r'RESULTS: (\d+) checks, (\d+) failures',text)
passed = bool(run.returncode==0 and footer and int(footer[2])==0 and 'SCRIPT ERROR:' not in text and 'FAIL ' not in text)
report = {'passed':passed,'checks':int(footer[1]) if footer else 0,'failures':int(footer[2]) if footer else None,
          'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'exit_code':run.returncode,
          'scope':'Embedded Windows UI smoke via explicit inspection flags, not a full exported mastery playthrough'}
(out/'result.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(text[-3000:]);print(json.dumps(report))
raise SystemExit(0 if passed else 1)
