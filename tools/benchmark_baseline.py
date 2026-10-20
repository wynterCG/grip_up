"""Preserve v133 starting identity before benchmark edits or physical runs."""
import sys,subprocess,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/auto_tuning'))
from common import DEST,atomic_json,file_hash,source_hashes,engine_identity,utc_now

def main():
    doc=ROOT/'docs/validation/auto_tuning/benchmark_v133';doc.mkdir(parents=True,exist_ok=True)
    assert not (doc/'baseline_manifest.json').exists()
    assert subprocess.check_output(['git','status','--porcelain'],cwd=DEST,text=True).strip()==''
    commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=DEST,text=True).strip()
    assert commit=='247f19060f7966a8b5fe547cfc5a91e62fa2c2a5'
    assert source_hashes(ROOT)==source_hashes(DEST)
    subprocess.run(['git','tag','baseline/pre-v133-benchmark',commit],cwd=DEST,check=True)
    subprocess.run(['git','switch','-c','feature/v1.3.3-benchmark-qualification'],cwd=DEST,check=True)
    paths=subprocess.check_output(['git','ls-files','docs/validation'],cwd=DEST,text=True).splitlines()
    protected={p:file_hash(DEST/p) for p in paths if (DEST/p).is_file()}
    raw={p.relative_to(ROOT).as_posix():file_hash(p) for name in ['requal_20261020_r1','projection_v132b_r1','projection_v132b_r2'] for p in (ROOT/'builds/eval_virtual_cursor'/name).rglob('*') if p.is_file()}
    extra=[ROOT/'project.godot',DEST/'project.godot',ROOT/'export_presets.cfg',DEST/'export_presets.cfg',Path(r'E:\Godot Games\janga_proto\runtime\physics_grabber.gd'),ROOT/'builds/GripUp-v1.2-pre-v1.3.exe']
    atomic_json(doc/'baseline_manifest.json',{'utc':utc_now(),'baseline_commit':commit,'measured_projection_commit':'da7ed73d3cb9832319eda9c78ae6393a01f34f76','engine':engine_identity(),'source_hashes':source_hashes(),'historical_tracked_evidence':protected,'historical_raw_evidence':raw,'protected_external':{str(p):file_hash(p) for p in extra},'source_override_C':'ABSENT' if not (ROOT/'override.cfg').exists() else file_hash(ROOT/'override.cfg'),'local_override_E':file_hash(DEST/'override.cfg'),'canonical_project':str(DEST),'working_mirror':str(ROOT),'optimizer':'OFF','private_holdout_outcomes_accessed':False})
    shutil.copyfile(Path(r'C:\Users\Wynter\Downloads\GRIP_UP_Auto_Tuning_Benchmark_Qualification_Spec_v1_3_3_EN.md'),doc/'implementation_spec.md')
    print('BQ0 baseline preserved',commit,len(protected),'historical documents',len(raw),'raw files')
if __name__=='__main__':main()
