#!/usr/bin/env python3
"""Build a reproducible root-level GIANTS mod ZIP after blocking XML/l10n checks.

Use --lua with a Lua 5.1 interpreter for a mandatory syntax pass in release builds.
This tool does not assert in-game visual/performance/compatibility validation.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys, tempfile, zipfile
from validateConfig import validate as validate_config
from validateLocalization import validate as validate_localization

LANGUAGES='en,de,jp,pl,cz,fr,es,ru,it,pt,hu,nl,cs,ct,br,tr,ro,kr,ea,da,fi,no,sv,fc,uk,vi,id'.split(',')
EXCLUDED={'.git','.github','__pycache__','.pytest_cache','tools','build','.gitignore'}
def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('output',type=Path,nargs='?',default=Path.cwd().parent/'FS25_Enhanced.zip'); p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]); p.add_argument('--sdk-profiles',type=Path); p.add_argument('--lua',required=True)
    a=p.parse_args(); root=a.root.resolve(); out=a.output.resolve()
    if out.is_relative_to(root): raise SystemExit('Output ZIP must be outside the source mod')
    for result in [validate_config(root,a.sdk_profiles),validate_localization(root/'l10n',LANGUAGES,True)]:
        if not result['ok']: print(json.dumps(result,ensure_ascii=False,indent=2)); return 1
    files=sorted(f for f in root.rglob('*') if f.is_file() and not set(f.relative_to(root).parts)&EXCLUDED and f.suffix not in {'.pyc','.zip','.bak'})
    with tempfile.TemporaryDirectory(prefix='fs25e_validate_') as tmp:
        check=Path(tmp)/'syntax.lua'; check.write_text("for _,p in ipairs(arg) do local fn,e=loadfile(p); assert(fn,e) end; print('PASS Lua syntax')",encoding='utf-8')
        subprocess.run([a.lua,str(check),*[str(f) for f in files if f.suffix=='.lua']],check=True)
    out.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as archive:
        for file in files:
            info=zipfile.ZipInfo(file.relative_to(root).as_posix(),date_time=(2026,9,11,0,0,0)); info.compress_type=zipfile.ZIP_DEFLATED
            archive.writestr(info,file.read_bytes())
    with zipfile.ZipFile(out) as archive:
        assert archive.testzip() is None and 'modDesc.xml' in archive.namelist()
    manifest={f.relative_to(root).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
    out.with_suffix('.manifest.json').write_text(json.dumps({'archiveSha256':hashlib.sha256(out.read_bytes()).hexdigest(),'files':manifest},indent=2),encoding='utf-8')
    print(f'PASS packaged {len(files)} files: {out.name}; visual/performance gates NOT_TESTED')
    return 0
if __name__=='__main__': sys.exit(main())
