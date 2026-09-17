#!/usr/bin/env python3
"""Validate mod XML, packaged paths, GIANTS GUI profiles, callbacks and presets."""
from pathlib import Path
import argparse, json, re, sys
import xml.etree.ElementTree as ET

def validate(root, sdk_profiles=None):
    root=Path(root).resolve(); errors=[]; trees={}
    for path in sorted(root.rglob('*.xml')):
        try: trees[path.relative_to(root).as_posix()]=ET.parse(path).getroot()
        except (ET.ParseError,OSError) as exc: errors.append(f'{path.name}: {exc}')
    desc=trees.get('modDesc.xml')
    if desc is None: return {'ok':False,'errors':errors+['modDesc.xml missing/invalid']}
    def packaged(name):
        path=(root/name).resolve()
        return path.is_relative_to(root) and path.is_file()
    refs=[]
    for node in desc.findall('.//sourceFile')+desc.findall('.//specialization')+desc.findall('.//placeableSpecialization'):
        name=node.get('filename',''); refs.append(name)
        if not packaged(name): errors.append(f'Missing or unsafe source path: {name}')
    if len(refs)!=len(set(refs)): errors.append('Duplicate source/specialization file')
    if not re.fullmatch(r'\d+\.\d+\.\d+\.\d+',desc.findtext('version','')): errors.append('Expected four-part version')
    if not packaged(desc.findtext('iconFilename','')): errors.append('Missing icon')
    builtin=set()
    if sdk_profiles:
        builtin={n.get('name') for n in ET.parse(sdk_profiles).getroot().findall('Profile')}
    lua='\n'.join(p.read_text(encoding='utf-8-sig') for p in (root/'scripts').rglob('*.lua'))
    callbacks=set(re.findall(r'function\s+[\w.]+[:.]([A-Za-z_]\w*)\s*\(',lua))
    native_menu_path=root/'scripts/UI/FS25E_GraphicsMenuIntegration.lua'
    if native_menu_path.is_file():  # removed in 0.5.8.0; the live window is the only interface
        native_menu=native_menu_path.read_text(encoding='utf-8')
        category_table=re.search(r"local categories=\{([^}]+)\}",native_menu)
        if category_table and "F['onClick_'..id]=function()" in native_menu:
            callbacks.update('onClick_'+name for name in re.findall(r"'([^']+)'",category_table.group(1)))
    # Inherited lifecycle/mouse/focus callbacks are supplied by GIANTS base classes.
    inherited={'onOpen','onClose','onGuiSetupFinished','onClickBack','onClickOk','onFocus','onLeave','onCreate'}
    for name,tree in trees.items():
        if not name.startswith('gui/'): continue
        custom={n.get('name') for n in tree.findall('.//GuiProfiles/Profile')}
        if tree.find('.//guiProfiles') is not None: errors.append(f'{name}: GuiProfiles is case-sensitive')
        ids=[n.get('id') for n in tree.iter() if n.get('id')]
        if len(ids)!=len(set(ids)): errors.append(f'{name}: duplicate GUI id')
        for node in tree.iter():
            for attr,value in node.attrib.items():
                if attr in {'profile','extends'} and sdk_profiles and value not in builtin|custom:
                    errors.append(f'{name}: unknown GUI profile {value}')
                if attr.startswith('on') and attr not in {'onText'} and value not in callbacks|inherited:
                    errors.append(f'{name}: missing callback {value}')
    presets=trees.get('config/presets.xml')
    if presets is None or {n.get('name') for n in presets.findall('preset')}!={'Performance','Balanced','Quality','Cinematic'}:
        errors.append('Expected exactly four distinct presets')
    elif any(len(p.findall('target'))!=len({n.get('key') for n in p.findall('target')}) for p in presets.findall('preset')):
        errors.append('Duplicate preset target')
    caps=trees.get('config/capabilityProfiles.xml')
    if caps is not None:
        ids=[n.get('id') for n in caps.findall('capability')]
        if len(ids)!=len(set(ids)): errors.append('Duplicate native capability')
    master=trees.get('l10n/l10n_en.xml')
    if master is not None:
        keys={n.get('name') for n in master.findall('texts/text')}
        for name,tree in trees.items():
            if not name.startswith('gui/'): continue
            for node in tree.iter():
                for value in node.attrib.values():
                    if value.startswith('$l10n_FS25E_') and value[len('$l10n_'):] not in keys:
                        errors.append(f'{name}: unknown translation {value}')
        catalog_path=root/'docs/CONTROL_CATALOG.json'
        if catalog_path.is_file():
            try:
                catalog=json.loads(catalog_path.read_text(encoding='utf-8'))
                if len(catalog)!=len({c['id'] for c in catalog}): errors.append('Duplicate control catalog ID')
                for control in catalog:
                    for attr in ['labelKey','tooltipKey']:
                        if control[attr] not in keys: errors.append(f'Control {control["id"]}: unknown {attr} {control[attr]}')
                    if control['step']<=0 or control['minimum']>control['maximum']: errors.append(f'Invalid control range: {control["id"]}')
            except (ValueError,KeyError) as exc: errors.append(f'Invalid control catalog: {exc}')
    return {'ok':not errors,'xmlFiles':len(trees),'sourceFiles':len(refs),'sdkProfilesChecked':bool(sdk_profiles),'errors':errors}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('root',nargs='?',type=Path,default=Path(__file__).resolve().parents[1]); p.add_argument('--sdk-profiles',type=Path); p.add_argument('--report',type=Path)
    a=p.parse_args(); result=validate(a.root,a.sdk_profiles)
    if a.report: a.report.write_text(json.dumps(result,indent=2),encoding='utf-8')
    for error in result['errors']: print('ERROR '+error)
    print(('PASS' if result['ok'] else 'FAIL')+' config '+json.dumps({k:v for k,v in result.items() if k!='errors'}))
    sys.exit(0 if result['ok'] else 1)
