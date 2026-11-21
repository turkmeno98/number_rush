#!/usr/bin/env python3
"""Build a reconstructed Roblox XML place from the conversation source snapshot.

This is not an export of the user's original Studio scene. No Roblox APIs run.
"""
from pathlib import Path
import hashlib
import json
import math
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def sources():
    result = []
    for file in sorted((ROOT / 'src').rglob('*.lua')):
        rel = file.relative_to(ROOT / 'src')
        filename = file.name
        if filename.endswith('.server.lua'):
            cls, name = 'Script', filename[:-11]
        elif filename.endswith('.client.lua'):
            cls, name = 'LocalScript', filename[:-11]
        else:
            cls, name = 'ModuleScript', filename[:-4]
        result.append({'source': file.relative_to(ROOT).as_posix(),
                       'studio_path': '/'.join([*rel.parts[:-1], name]),
                       'class': cls,
                       'sha256': hashlib.sha256(file.read_bytes()).hexdigest()})
    return result

def build():
    root = ET.Element('roblox', version='4')
    ET.SubElement(root, 'External').text = 'null'
    ET.SubElement(root, 'External').text = 'nil'
    by_path = {}
    serial = 0

    def item(parent, cls, name):
        nonlocal serial
        serial += 1
        node = ET.SubElement(parent, 'Item', {'class': cls, 'referent': f'RBX{serial:08d}'})
        props = ET.SubElement(node, 'Properties')
        ET.SubElement(props, 'string', name='Name').text = name
        return node

    def prop(node, tag, name, text):
        p = ET.SubElement(node.find('Properties'), tag, name=name)
        p.text = str(text)
        return p

    def vector(node, name, values):
        v = ET.SubElement(node.find('Properties'), 'Vector3', name=name)
        for axis, value in zip('XYZ', values):
            ET.SubElement(v, axis).text = str(value)

    def cframe(node, name, position, rows=None):
        cf = ET.SubElement(node.find('Properties'), 'CoordinateFrame', name=name)
        for axis, value in zip('XYZ', position):
            ET.SubElement(cf, axis).text = str(value)
        rows = rows or ((1,0,0),(0,1,0),(0,0,1))
        for i in range(3):
            for j in range(3):
                ET.SubElement(cf, f'R{i}{j}').text = str(rows[i][j])

    for cls in ['Workspace','Players','Lighting','ReplicatedStorage','ServerScriptService','StarterGui','StarterPlayer']:
        by_path[cls] = item(root, cls, cls)
    by_path['StarterPlayer/StarterPlayerScripts'] = item(by_path['StarterPlayer'], 'StarterPlayerScripts', 'StarterPlayerScripts')
    by_path['ReplicatedStorage/NumberRushRemotes'] = item(by_path['ReplicatedStorage'], 'Folder', 'NumberRushRemotes')
    for name in ['SpinRequest','SpinResult','SlotRequest','SlotResult','ProgressRequest','ProgressResult']:
        item(by_path['ReplicatedStorage/NumberRushRemotes'], 'RemoteEvent', name)

    trading_path = 'ServerScriptService/NR_TradingFoundation'
    by_path[trading_path] = item(by_path['ServerScriptService'], 'Folder', 'NR_TradingFoundation')

    entries = sources()
    for entry in entries:
        parent_path, name = entry['studio_path'].rsplit('/', 1)
        node = item(by_path[parent_path], entry['class'], name)
        prop(node, 'ProtectedString', 'Source', (ROOT / entry['source']).read_text(encoding='utf-8'))

    workspace = by_path['Workspace']
    item(workspace, 'Terrain', 'Terrain')
    base = item(workspace, 'Part', 'Baseplate')
    prop(base, 'bool', 'Anchored', 'true')
    vector(base, 'Size', (512,1,512))
    cframe(base, 'CFrame', (0,-.5,0))
    spawn = item(workspace, 'SpawnLocation', 'SpawnLocation')
    prop(spawn, 'bool', 'Anchored', 'true')
    prop(spawn, 'bool', 'Neutral', 'true')
    vector(spawn, 'Size', (12,1,12))
    cframe(spawn, 'CFrame', (0,.5,0))
    camera = item(workspace, 'Camera', 'Camera')
    x,y,z=32,20,32
    length=math.sqrt(x*x+y*y+z*z)
    back=(x/length,y/length,z/length)
    flat=math.sqrt(x*x+z*z)
    right=(z/flat,0,-x/flat)
    up=(back[1]*right[2],back[2]*right[0]-back[0]*right[2],-back[1]*right[0])
    rotation=tuple(tuple(axis[i] for axis in (right,up,back)) for i in range(3))
    cframe(camera, 'CFrame', (x,y,z), rotation)
    cframe(camera, 'Focus', (0,0,0))
    prop(camera, 'float', 'FieldOfView', 70)
    prop(workspace, 'Ref', 'CurrentCamera', camera.get('referent'))
    prop(by_path['Lighting'], 'float', 'ClockTime', 14)
    prop(by_path['Lighting'], 'float', 'Brightness', 2)

    ET.indent(root, space='  ')
    output = ROOT / 'places/NUMBER_RUSH_reconstructed.rbxlx'
    output.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(root).write(output, encoding='utf-8', xml_declaration=True)

    manifest = {
        'checkpoint': '2026-11-21-step-38-with-studio-trading-foundation',
        'provenance': 'Reconstructed from repository sources verified against Studio; includes nine Studio trading modules, without original scene geometry',
        'original_rbxl_received': False,
        'generated_place': output.relative_to(ROOT).as_posix(),
        'sources': entries,
        'remote_events': ['ReplicatedStorage/NumberRushRemotes/' + name for name in ['SpinRequest','SpinResult','SlotRequest','SlotResult','ProgressRequest','ProgressResult']],
        'excluded_disabled_scripts': ['DataStoreCheck','NumberRulesTest','BalanceSaveTest'],
    }
    (ROOT / 'snapshot_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n', encoding='utf-8', newline='\n')

    # Optional standard filesystem mapping. Rojo is not required for restoration.
    client_tree = {'$className':'StarterPlayerScripts'}
    for entry in entries:
        if entry['studio_path'].startswith('StarterPlayer/StarterPlayerScripts/'):
            client_tree[entry['studio_path'].rsplit('/',1)[1]] = {'$path':entry['source']}
    project = {'name':'NUMBER RUSH','tree':{
        '$className':'DataModel',
        'Workspace':{'$className':'Workspace','$ignoreUnknownInstances':True},
        'ReplicatedStorage':{'$className':'ReplicatedStorage',
            'GameConfig':{'$path':'src/ReplicatedStorage/GameConfig.lua'},
            'NumberRushRemotes':{'$className':'Folder','SpinRequest':{'$className':'RemoteEvent'},'SpinResult':{'$className':'RemoteEvent'},'SlotRequest':{'$className':'RemoteEvent'},'SlotResult':{'$className':'RemoteEvent'},'ProgressRequest':{'$className':'RemoteEvent'},'ProgressResult':{'$className':'RemoteEvent'}}},
        'ServerScriptService':{'$className':'ServerScriptService','$path':'src/ServerScriptService'},
        'StarterPlayer':{'$className':'StarterPlayer','StarterPlayerScripts':client_tree},
    }}
    for entry in entries:
        if entry['studio_path'].startswith('ReplicatedStorage/') and entry['studio_path'].count('/') == 1:
            project['tree']['ReplicatedStorage'][entry['studio_path'].rsplit('/',1)[1]] = {'$path':entry['source']}
    (ROOT/'default.project.json').write_text(json.dumps(project,ensure_ascii=False,indent=2)+'\n', encoding='utf-8', newline='\n')
    print(f'Built {output.relative_to(ROOT)} with {len(entries)} source scripts.')

if __name__ == '__main__':
    build()
