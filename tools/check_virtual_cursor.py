"""Parser/contract process: no physics world, no qualification cell."""
from pathlib import Path
import subprocess,time
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'builds/eval_virtual_cursor/contracts'/str(time.time_ns())
out.mkdir(parents=True)
with (out/'stdout.txt').open('wb') as stdout,(out/'stderr.txt').open('wb') as stderr:
 p=subprocess.Popen([str(Path.home()/'WrapRush/tools/godot.exe'),'--headless','--path',str(ROOT),'--script','res://features/evaluator_virtual_cursor/scripts/test_input_contract.gd'],stdout=stdout,stderr=stderr)
 try:code=p.wait(timeout=40)
 except subprocess.TimeoutExpired:p.kill();p.wait();code=124
for name in ['stdout.txt','stderr.txt']:print((out/name).read_text(errors='replace'))
print('EXIT',code,'RECEIPT',out)
raise SystemExit(code)
