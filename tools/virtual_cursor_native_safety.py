"""Supplementary Godot MCP Pro safety inspection; exact local config restoration."""
from pathlib import Path
import json,sys,subprocess,time,hashlib
ROOT=Path(__file__).resolve().parents[1];DEST=Path(r'E:\Godot Games\grip_up')
ENGINE=Path.home()/'WrapRush/tools/godot.exe'
OUT=ROOT/'builds/eval_virtual_cursor/native'
OUT.mkdir(parents=True,exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(name,value):(OUT/name).write_text(json.dumps(value,indent=2),encoding='utf-8')
def start():
    assert not (OUT/'editor_process.json').exists(),'Owned editor already recorded'
    for label,base in [('C',ROOT),('E',DEST)]:
        (OUT/f'project_before_{label}.godot').write_bytes((base/'project.godot').read_bytes())
    original=(DEST/'project.godot').read_bytes()
    assert b'[editor_plugins]' not in original
    (DEST/'project.godot').write_bytes(original+b'\n[editor_plugins]\nenabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")\n')
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    log=(OUT/'editor.log').open('wb')
    process=subprocess.Popen([str(ENGINE),'--editor','--path',str(DEST),'--screen','0','--rendering-method','gl_compatibility'],stdout=log,stderr=log,startupinfo=startup)
    save('editor_process.json',{'pid':process.pid,'project':str(DEST),'monitor_index':0,'scope':'SUPPLEMENTARY_ONLY ordinary LIVE/default safety; not V0 qualification'})
    print('Owned editor PID',process.pid)
def mcp(name,group,command,params):
    request=OUT/f'{name}_request.json';request.write_text(json.dumps({'group':group,'command':command,'params':params}),encoding='utf-8')
    result=subprocess.run([sys.executable,str(ROOT/'tools/project.py'),'mcp',str(request)],capture_output=True,timeout=65)
    (OUT/f'{name}_cli.txt').write_bytes(result.stdout+result.stderr)
    (OUT/f'{name}_response.json').write_bytes((ROOT/'builds/mcp_last.log').read_bytes())
    raw=(ROOT/'builds/mcp_last.log').read_text(encoding='utf-8-sig');value=json.JSONDecoder().raw_decode(raw)[0]
    print(name,json.dumps(value,ensure_ascii=True)[:2000])
    if result.returncode:raise RuntimeError('MCP failure')
    return value
def restore():
    record=json.loads((OUT/'editor_process.json').read_text())
    query=f"Get-CimInstance Win32_Process -Filter 'ProcessId = {int(record['pid'])}' | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"
    raw=subprocess.check_output(['powershell','-NoProfile','-Command',query],text=True)
    if raw.strip():
        actual=json.loads(raw);assert '--editor' in actual['CommandLine'] and str(DEST) in actual['CommandLine']
        subprocess.run(['taskkill','/PID',str(record['pid']),'/F'],capture_output=True,check=True)
        for _ in range(30):
            if not subprocess.check_output(['powershell','-NoProfile','-Command',query],text=True).strip():break
            time.sleep(.1)
        else:raise RuntimeError('EDITOR_NOT_CLOSED')
    (OUT/'project_after_editor.godot').write_bytes((DEST/'project.godot').read_bytes())
    for label,base in [('C',ROOT),('E',DEST)]:(base/'project.godot').write_bytes((OUT/f'project_before_{label}.godot').read_bytes())
    save('restoration.json',{'project_C_restored':sha(ROOT/'project.godot')==sha(OUT/'project_before_C.godot'),'project_E_restored':sha(DEST/'project.godot')==sha(OUT/'project_before_E.godot'),'original_sha256':sha(OUT/'project_before_C.godot'),'owned_editor_closed':True})
    print('Exact project settings restored after owned editor exit')
if __name__=='__main__':
    if sys.argv[1]=='start':start()
    elif sys.argv[1]=='restore':restore()
    elif sys.argv[1]=='inspect':
        mcp('errors_before','editor','errors',{})
        mcp('play_main','scene','play',{'mode':'main'})
    elif sys.argv[1]=='runtime':
        previous=json.loads((ROOT/'builds/eval_v132/native/normal_runtime_request.json').read_text())['params']['code']
        previous=previous.replace('"native_mode":"ordinary_main_after_review"','"native_mode":"ordinary_main_v132a"')
        previous=previous.replace('"profile":a.input_profile','"virtual_provider_disabled":a.replay_input_provider==null,"virtual_arming":a.virtual_input_arming,"camera_virtual":a.camera.virtual_physics_follow,"source_kind":a.input_frame.data().source_kind,"profile":a.input_profile')
        mcp('normal_runtime','runtime','exec',{'code':previous})
        path=(OUT/'normal_main.png').as_posix()
        mcp('screenshot','runtime','exec',{'code':f'var err=get_viewport().get_texture().get_image().save_png("{path}")\n_mcp_print(JSON.stringify({{"saved":err==OK,"path":"{path}"}}))'})
        mcp('errors_after','editor','errors',{})
        mcp('stop_main','scene','stop',{})
