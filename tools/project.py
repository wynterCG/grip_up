"""Local project tasks with explicit destinations and captured Godot output."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import sys
sys.stdout.reconfigure(encoding='utf-8',errors='replace')

ROOT = Path(__file__).resolve().parents[1]
DEST = Path(r'E:\Godot Games\grip_up')
ENGINE = Path(r'C:\Users\Wynter\WrapRush\tools\godot.exe')
CLI = Path(r'C:\Users\Wynter\Downloads\godot-mcp-pro-v1.17.1\server\build\cli.js')
BUILD_NAME = 'GripUp-v0.7.1.exe'

parser = argparse.ArgumentParser()
parser.add_argument('task', choices=['sync','test','test-saved','editor','mcp','export','cleanup','smoke'])
parser.add_argument('extra', nargs='*')
args = parser.parse_args()
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0

if args.task == 'cleanup':
    # Only stale instances of this new prototype, never another Godot project.
    query = "Get-CimInstance Win32_Process -Filter \"name = 'godot.exe'\" | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"
    raw = subprocess.check_output(['powershell','-NoProfile','-Command',query],text=True)
    processes=json.loads(raw) if raw.strip() else []
    if isinstance(processes,dict): processes=[processes]
    for process in processes:
        command=process.get('CommandLine') or ''
        if ('C:\\Users\\Wynter\\grip_up' in command and '--headless' in command) or (process['ProcessId']==9520 and 'E:\\Godot Games\\grip_up' in command and '--editor' in command):
            subprocess.run(['taskkill','/PID',str(process['ProcessId']),'/F'],capture_output=True,check=True)
            print('Stopped prototype instance',process['ProcessId'])
elif args.task == 'sync':
    assert str(DEST.resolve()).lower() == r'e:\godot games\grip_up'
    DEST.mkdir(parents=True, exist_ok=True)
    for name in ['features','tools','docs']:
        shutil.copytree(ROOT/name, DEST/name, dirs_exist_ok=True, ignore=shutil.ignore_patterns('__pycache__'))
    for name in ['project.godot','.gitignore','README.md','export_presets.cfg']:
        if (ROOT/name).exists(): shutil.copy2(ROOT/name, DEST/name)
    # The licensed local plugin is enabled by ignored override.cfg, not by the
    # portable project settings committed to Git.
    (DEST/'builds').mkdir(exist_ok=True)
    for name in [BUILD_NAME,'verification.json','decision.md']:
        if (ROOT/'builds'/name).exists(): shutil.copy2(ROOT/'builds'/name, DEST/'builds'/name)
    # Licensed editor plugin stays local and is excluded from exported builds.
    addon = DEST/'addons'/'godot_mcp'
    if not addon.exists():
        shutil.copytree(ROOT/'addons'/'godot_mcp', addon)
    (DEST/'override.cfg').write_text('[autoload]\nMCPGameInspector="*res://addons/godot_mcp/mcp_game_inspector_service.gd"\nMCPInputService="*res://addons/godot_mcp/mcp_input_service.gd"\nMCPScreenshot="*res://addons/godot_mcp/mcp_screenshot_service.gd"\n\n[editor_plugins]\nenabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")\n',encoding='utf-8')
    print('Project saved:',DEST)
elif args.task == 'editor':
    log = ROOT/'builds'/'editor.log'
    handle = log.open('wb')
    process = subprocess.Popen([str(ENGINE),'--editor','--path',str(DEST),'--rendering-method','gl_compatibility'],stdout=handle,stderr=handle,startupinfo=startup)
    print('Editor PID',process.pid,'project',DEST)
elif args.task == 'mcp':
    request = json.loads(Path(args.extra[0]).read_text(encoding='utf-8-sig'))
    command = ['node',str(CLI),request['group'],request['command']]
    for key,value in request.get('params',{}).items():
        command.extend(['--'+key,value if isinstance(value,str) else json.dumps(value)])
    result = subprocess.run(command,capture_output=True,timeout=60)
    target = ROOT/'builds'/'mcp_last.log'
    target.write_bytes(result.stdout+result.stderr)
    if len(result.stdout)<10000: print(result.stdout.decode(errors='replace'))
    else: print('Large MCP response saved:',target)
    print(result.stderr.decode(errors='replace'))
    sys.exit(result.returncode)
else:
    if args.task in ['test','test-saved']:
        script = args.extra[0]
        assert '/' not in script and '\\' not in script
        command=[str(ENGINE),'--headless','--path',str(DEST if args.task=='test-saved' else ROOT),'--script',f'res://features/grip_up/tests/{script}.gd','--fixed-fps','120','--quit-after','20000']
        if len(args.extra)>1: command += ['--'] + args.extra[1:]
    elif args.task == 'smoke':
        command=[str(ROOT/'builds'/BUILD_NAME),'--write-movie',str(ROOT/'builds'/'export.png'),'--fixed-fps','60','--quit-after','3']
    else:
        command=[str(ENGINE),'--headless','--path',str(ROOT),'--export-debug','Windows PC',str(ROOT/'builds'/BUILD_NAME)]
    result=subprocess.run(command,capture_output=True,startupinfo=startup,timeout=180)
    output=(result.stdout+result.stderr).decode('utf-8',errors='replace')
    suffix = '_' + '_'.join(value.lstrip('-') for value in args.extra[1:]) if len(args.extra)>1 else ''
    (ROOT/'builds'/f'{args.task}_{args.extra[0] if args.extra else "export"}{suffix}.log').write_text(output,encoding='utf-8')
    print(output if args.task!='export' else output[-2200:])
    if args.task in ['test','test-saved'] and ('RESULTS:' not in output or 'SCRIPT ERROR:' in output or 'FAIL ' in output): sys.exit(1)
    sys.exit(result.returncode)
