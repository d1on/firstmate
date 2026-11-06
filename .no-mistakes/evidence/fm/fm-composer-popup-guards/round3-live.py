import os, subprocess, time, json, re, html
from pathlib import Path
root=Path.cwd(); E=Path('/Users/dion/.no-mistakes/evidence/01M6QSN9FAK9FEV37TK4WBEWHR'); out=E/'round3-live'; out.mkdir(exist_ok=True)
lab=root/'.l'; lab.mkdir()
subprocess.run(['bash','bin/fm-lab-home.sh','create',str(lab)],check=True)
(lab/'tmux').mkdir(); (lab/'config/supervision-host').touch(); (lab/'home').mkdir(); (lab/'claude').mkdir()
# UI preferences only: no credential, account, or login fixture.
(lab/'claude/.claude.json').write_text(json.dumps({'hasCompletedOnboarding':True,'theme':'dark','projects':{str(root):{'hasTrustDialogAccepted':True}}}))
env=dict(os.environ,TMUX_TMPDIR=str(lab/'tmux'),HOME=str(lab/'home'),CLAUDE_CONFIG_DIR=str(lab/'claude'),DISABLE_AUTOUPDATER='1',CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN='1')
for key in ['NO_MISTAKES_GATE','FM_GATE_REFUSE_BYPASS','FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_CONFIG_OVERRIDE','FM_PROJECTS_OVERRIDE']: env.pop(key,None)
def t(*a): return subprocess.check_output(['tmux','-L','fm-lab',*a],env=env,text=True)
def key(*a): t('send-keys','-t','primary',*a)
records=[]; matched=False
caps='styled=1\ncursor=0\nidentity=0\nrows=0'
def snap(label, probes=False):
 global matched
 ansi=t('capture-pane','-e','-p','-t','primary'); plain=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',ansi)
 name=f'{len(records):03}-{label}'; (out/(name+'.ansi')).write_text(ansi); (out/(name+'.txt')).write_text(plain)
 lines=plain.splitlines()
 def rule(s): return len(s.strip())>=8 and set(s.strip())=={'─'}
 old=[i for i,s in enumerate(lines) if re.fullmatch(r'\s*❯\s*/exit\s*',s) and i>0 and i+1<len(lines) and rule(lines[i-1]) and rule(lines[i+1])]
 draft=[i for i,s in enumerate(lines) if re.match(r'\s*❯\s*/exit!\s+real draft',s)]
 geometry=any(d>o+1 and not(d>0 and d+1<len(lines) and rule(lines[d-1]) and rule(lines[d+1])) for o in old for d in draft)
 selected={}
 for h in (['claude','','codex','kiro'] if probes else ['claude']):
  result=subprocess.run(['bash','-c','. bin/fm-composer-lib.sh; fm_composer_extract_selected_content "$1" "$2"','probe',caps,ansi],env=dict(os.environ,FM_COMPOSER_HARNESS=h),text=True,capture_output=True)
  selected[h or 'unknown']=result.stdout.strip() if result.returncode==0 else 'REFUSED (status '+str(result.returncode)+')'
 r=dict(capture=name,older_composer_rows=old,invalid_draft_rows=draft,required_geometry=geometry,selected=selected); records.append(r); print(json.dumps(r),flush=True)
 (out/'observations.json').write_text(json.dumps(records,indent=2))
 if geometry:
  matched=True
  if selected['claude']!='/exit! real draft': raise RuntimeError('REAL DEFECT: stop and report')
 return plain
try:
 cli=str(root/'.live-tools/node_modules/@anthropic-ai/claude-code-darwin-arm64/claude')
 print(subprocess.check_output([cli,'--version'],env=env,text=True).strip(),flush=True)
 t('new-session','-d','-s','primary','-x','120','-y','40','-c',str(root),'-e','FM_HOME='+str(lab),cli+' --bare --setting-sources "" --tools ""')
 time.sleep(6); startup=snap('startup')
 if '❯' not in startup: raise RuntimeError('Composer not ready; inspect startup')
 key('-l','/exit'); time.sleep(.6); snap('popup',True)
 # Try cancellation and reopening around real invalid-draft input, rather than
 # replaying the earlier resize/Ctrl-L-only attempt.
 for action in ['escape','ctrl-c','multiline','paste','rapid-popup','short-grid']:
  key('Escape'); time.sleep(.1); key('C-c'); time.sleep(.2); key('-l','/exit'); time.sleep(.4); snap(action+'-old')
  if action=='escape': key('Escape'); key('-l','!  real draft')
  elif action=='ctrl-c': key('C-c'); key('-l','/exit!  real draft')
  elif action=='multiline': key('Escape','Escape'); key('-l','!  real draft'); key('Escape','Enter')
  elif action=='paste':
   # Terminal bracketed paste of actual keyboard text, no injected display rows.
   key('-l','\x1b[200~!  real draft\x1b[201~')
  elif action=='rapid-popup':
   for _ in range(5): key('-l','!'); key('BSpace')
   key('-l','!  real draft')
  elif action=='short-grid':
   t('resize-window','-t','primary','-x','80','-y','8'); key('-l','!  real draft')
  snap(action+'-immediate'); time.sleep(.5); snap(action+'-settled')
  if matched: break
  if action=='short-grid':
   t('resize-window','-t','primary','-x','120','-y','40'); time.sleep(.4); snap('restored-grid')
 print(json.dumps({'required_geometry_seen':matched,'captures':len(records)}),flush=True)
finally:
 try: t('kill-server')
 except subprocess.CalledProcessError: pass
 import shutil; shutil.rmtree(lab)
 # Render actual captured terminal cells, not a fabricated target arrangement.
 sections=[]
 for r in records:
  if r['capture'].endswith(('popup','escape-settled','paste-settled','short-grid-settled')):
   s=(out/(r['capture']+'.txt')).read_text(); sections.append('<h2>'+html.escape(r['capture'])+'</h2><pre>'+html.escape(s)+'</pre>')
 (E/'round3-terminal.html').write_text('<!doctype html><meta charset="utf-8"><title>Real Claude terminal captures</title><style>body{background:#151515;color:#ddd;font:14px monospace}pre{white-space:pre;border:1px solid #555;padding:16px}h2{font-size:16px}</style><h1>Real Claude 2.1.303 terminal captures</h1><p>Actual tmux screen cells; no synthetic draft geometry.</p>'+''.join(sections))
