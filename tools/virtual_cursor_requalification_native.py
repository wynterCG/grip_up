"""New MCP safety receipts, preserving all previous native sessions."""
from pathlib import Path
import json,sys
import virtual_cursor_native_safety as native
ROOT=Path(__file__).resolve().parents[1]
native.OUT=ROOT/'builds/eval_virtual_cursor/requal_20261020_r1/native'
native.OUT.mkdir(parents=True,exist_ok=True)
stage=sys.argv[1]
if stage=='start':native.start()
elif stage=='inspect':
    native.mcp('errors_before','editor','errors',{})
    native.mcp('play_main','scene','play',{'mode':'main'})
elif stage=='runtime':
    code=json.loads((ROOT/'builds/eval_v132/native/normal_runtime_request.json').read_text())['params']['code']
    code=code.replace('"profile":a.input_profile','"provider_disabled":a.replay_input_provider==null,"camera_virtual":a.camera.virtual_physics_follow,"source_kind":a.input_frame.data().source_kind,"profile":a.input_profile')
    native.mcp('normal_runtime','runtime','exec',{'code':code})
    path=(native.OUT/'ordinary_main.png').as_posix()
    native.mcp('screenshot','runtime','exec',{'code':f'var err=get_viewport().get_texture().get_image().save_png("{path}")\n_mcp_print(JSON.stringify({{"saved":err==OK}}))'})
    native.mcp('errors_after','editor','errors',{})
    native.mcp('stop_main','scene','stop',{})
elif stage=='restore':native.restore()
