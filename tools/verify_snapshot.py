#!/usr/bin/env python3
"""Validate archive integrity and the reconstructed instance tree, not Luau runtime."""
from pathlib import Path
import hashlib
import json
import re
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'snapshot_manifest.json').read_text())
project=json.loads((ROOT/'default.project.json').read_text())
assert project['tree']['$className']=='DataModel'
assert manifest['original_rbxl_received'] is False
tree=ET.parse(ROOT/manifest['generated_place'])
instances={}
def walk(parent,prefix=''):
    for item in parent.findall('Item'):
        name=item.find("Properties/string[@name='Name']").text
        path=f'{prefix}/{name}' if prefix else name
        assert path not in instances,path
        instances[path]=item
        walk(item,path)
walk(tree.getroot())
assert len(manifest['sources'])==9
for entry in manifest['sources']:
    file=ROOT/entry['source']
    assert hashlib.sha256(file.read_bytes()).hexdigest()==entry['sha256'],file
    item=instances[entry['studio_path']]
    assert item.get('class')==entry['class'],entry
    source=item.find("Properties/ProtectedString[@name='Source']").text
    assert source==file.read_text(),entry
for path in manifest['remote_events']:
    assert instances[path].get('class')=='RemoteEvent'
for name in manifest['excluded_disabled_scripts']:
    assert f'ServerScriptService/{name}' not in instances
config=(ROOT/'src/ReplicatedStorage/GameConfig.lua').read_text()
assert config.rstrip().endswith('return Config')
codes=re.findall(r'Code = "(\d{3})"',config)
assert len(codes)==len(set(codes))==12
weights=re.findall(r'Weights = \{([^}]+)\}',config)
assert len(weights)==3
for row in weights:
    values=list(map(int,re.findall(r'\d+',row)))
    assert len(values)==6 and sum(values)==10000000
server=(ROOT/'src/ServerScriptService/GameServer.server.lua').read_text()
assert 'ErrorCode = code' in server
assert 'SpinService.Recover(session)' in server
assert 'session.BalanceValue = rubles' in server
ui=(ROOT/'src/StarterPlayer/StarterPlayerScripts/NumberRushUI.client.lua').read_text()
assert 'WaitForChild("leaderstats", 30)' in ui
assert 'requestRemote:FireServer(code, sequence)' in ui
assert 'WindowScale' not in ui
assert 'SetCoreGuiEnabled' not in ui
assert (ROOT/'docs/HANDOFF.md').is_file()
assert (ROOT/'docs/BALANCE_V02.md').is_file()
assert (ROOT/'AGENTS.md').is_file()
print('PASS: 9 source hashes and XML Source roundtrips; instance classes; 2 RemoteEvents; disabled probes excluded; 12 unique codes; 3 weight totals; checkpoint documents.')
print('Not executed: Luau runtime, Studio import, DataStore operations, multiplayer fault cases.')
