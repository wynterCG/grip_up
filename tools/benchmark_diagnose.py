"""Four issue-specific environment-only probes after the BQ1 hard stop."""
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/auto_tuning'))
from common import ENGINE, atomic_json, read_json, source_hashes, file_hash, StudyLock
BASE = ROOT / 'builds/eval_virtual_cursor/benchmark_v133_r1'

SCRIPT = '''extends SceneTree
class Clock extends Node:
	signal sample(delta:float)
	func _physics_process(delta:float)->void:sample.emit(delta)
func snap()->Dictionary:
	return {"size":[root.size.x,root.size.y],"mode":root.mode,"position":[root.position.x,root.position.y],"screen":root.current_screen,"visible_size":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"content_scale_size":[root.content_scale_size.x,root.content_scale_size.y],"content_scale_mode":root.content_scale_mode,"content_scale_aspect":root.content_scale_aspect,"display_server":DisplayServer.get_name()}
func _initialize()->void:run.call_deferred()
func run()->void:
	var before:=snap()
	var initialized:=INITIALIZE
	if initialized:root.size=Vector2i(1024,576)
	Engine.physics_ticks_per_second=HZ
	var clock:=Clock.new();root.add_child(clock)
	var samples:Array=[];var streak:=0
	for i in 12:
		var delta:float=await clock.sample
		samples.append(delta);streak=streak+1 if absf(delta-1.0/HZ)<.0000001 else 0
		if streak>=2:break
	var result={"scope":"ENVIRONMENT_DIAGNOSTIC_NOT_QUALIFICATION","before":before,"after":snap(),"explicit_size_initialization":initialized,"clock_samples":samples,"clock_settled":streak>=2,"gameplay_bodies_created":0,"physics_outcomes":0}
	var file:=FileAccess.open("TARGET",FileAccess.WRITE);file.store_string(JSON.stringify(result,"",true,true));file.close()
	quit(0)
'''

def main():
    assert not (BASE / 'diagnostics_session.json').exists()
    frozen = read_json(BASE / 'source_identity.json')
    assert source_hashes() == frozen['source_hashes']
    runs = []
    cases = [('D1_headless_cli', 120, 'headless', False),
             ('D2_rendered_cli', 120, 'rendered_scripted', False),
             ('D3_headless_explicit_initialization', 120, 'headless', True),
             ('D4_headless60_explicit_initialization', 60, 'headless', True)]
    with StudyLock(ROOT / 'builds/eval_virtual_cursor'):
        for name, hz, mode, initialize in cases:
            directory = BASE / 'attempts' / name
            directory.mkdir(parents=True, exist_ok=False)
            script = directory / 'environment_diagnostic.gd'
            script.write_text(SCRIPT.replace('INITIALIZE', str(initialize).lower()).replace('HZ', str(hz)).replace('TARGET', (directory / 'result.json').as_posix()), encoding='utf-8')
            flags = ['--headless', '--fixed-fps', '120'] if mode == 'headless' else ['--screen', '0', '--position', '80,80']
            command = [str(ENGINE), *flags, '--resolution', '1024x576', '--path', str(ROOT), '--script', str(script)]
            atomic_json(directory / 'manifest.json', {'run_id': name, 'budget_group': 'diagnostic', 'physics_hz': hz, 'engine_mode': mode, 'command': command, 'frozen_source_commit': frozen['repository_commit'], 'diagnostic_script_sha256': file_hash(script), 'does_not_requalify_failed_campaign': True})
            with (directory / 'stdout.txt').open('wb') as stdout, (directory / 'stderr.txt').open('wb') as stderr:
                process = subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr)
                try:
                    code = process.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait(); code = 124
            result = read_json(directory / 'result.json') if (directory / 'result.json').exists() else {}
            receipt = {'name': name, 'directory': str(directory), 'exit_code': code, 'result': result}
            runs.append(receipt)
            atomic_json(directory / 'receipt.json', receipt)
            atomic_json(BASE / 'diagnostics_session.json', {'runs': runs, 'primary_campaign_stays_stopped': True, 'gameplay_worlds': 0, 'optimizer': 'OFF'})
            print(name, code, result, flush=True)
    assert source_hashes() == frozen['source_hashes']

if __name__ == '__main__':
    main()
