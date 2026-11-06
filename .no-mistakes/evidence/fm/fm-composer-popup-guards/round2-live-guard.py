import subprocess, os, time, json, re
from pathlib import Path
root=Path.cwd()
evidence=Path('/Users/dion/.no-mistakes/evidence/01M6QSN9FAK9FEV37TK4WBEWHR')
out=evidence/'round2-live-guard'
out.mkdir(exist_ok=True)
sock=str(root/'.l/s')
def t(*args):
    return subprocess.check_output(['tmux','-S',sock,*args],text=True)
def keys(*args): t('send-keys','-t','guard',*args)
records=[]
def snap(label):
    plain=t('capture-pane','-p','-t','guard')
    ansi=t('capture-pane','-e','-p','-t','guard')
    n=len(records)
    name=f'{n:03}-{label}'
    (out/(name+'.txt')).write_text(plain)
    (out/(name+'.ansi')).write_text(ansi)
    lines=plain.splitlines()
    # Observable screen contract: the exact older /exit composer enclosed by
    # solid rules, followed below its closing rule by the invalid-draft row.
    def rule(s): return len(s.strip())>=8 and set(s.strip())=={'─'}
    old=[i for i,s in enumerate(lines) if re.fullmatch(r'\s*❯\s*/exit\s*',s) and i>0 and i+1<len(lines) and rule(lines[i-1]) and rule(lines[i+1])]
    draft=[i for i,s in enumerate(lines) if re.match(r'\s*❯\s*/exit!\s+real draft',s)]
    geometry=any(d>o+1 for o in old for d in draft)
    caps='styled=1\ncursor=0\nidentity=0\nrows=0'
    env=dict(os.environ,FM_COMPOSER_HARNESS='claude')
    actual=subprocess.check_output(['bash','-c','. bin/fm-composer-lib.sh; fm_composer_extract_selected_content "$1" "$2"','guard',caps,ansi],env=env,text=True).strip()
    records.append(dict(capture=name,old_rows=old,draft_rows=draft,required_geometry=geometry,selected=actual))
    (out/'observations.json').write_text(json.dumps(records,indent=2))
    if geometry:
        print('REQUIRED GEOMETRY',name,'selected',repr(actual),flush=True)
        if actual!='/exit! real draft': raise RuntimeError('Product defect: stop and report')
        raise SystemExit(0)
snap('initial-popup')
keys('-l','!  real draft')
for delay in [0,0.1,0.5]:
    time.sleep(delay); snap('append-invalid')
# Actual vendor redraws only: keyboard editing and terminal size changes.
for width,height in [(80,24),(60,12),(120,40),(120,16),(80,40),(120,40)]:
    keys('C-a','C-k'); keys('-l','/exit'); time.sleep(.3)
    snap(f'popup-{width}x{height}-before')
    t('resize-window','-t','guard','-x',str(width),'-y',str(height))
    keys('-l','!  real draft')
    snap(f'invalid-{width}x{height}-immediate')
    time.sleep(.3); snap(f'invalid-{width}x{height}-settled')
    keys('C-l'); time.sleep(.2); snap(f'invalid-{width}x{height}-ctrl-l')
print(json.dumps({'captures':len(records),'required_geometry_seen':any(r['required_geometry'] for r in records),'invalid_draft_seen':sum(bool(r['draft_rows']) for r in records)},indent=2))
