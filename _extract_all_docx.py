# -*- coding: utf-8 -*-
import zipfile, re, glob, os

def extract(path):
    xml = zipfile.ZipFile(path).read('word/document.xml').decode('utf-8')
    xml = xml.replace('</w:tc>', ' | ')
    xml = xml.replace('</w:tr>', '\n')
    xml = xml.replace('</w:p>', '\n')
    xml = xml.replace('<w:tab/>', '\t')
    xml = xml.replace('<w:br/>', '\n')
    text = re.sub(r'<[^>]+>', '', xml)
    text = re.sub(r'[ \t]*\|[ \t]*\n', '\n', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text

paths = sorted(glob.glob(os.path.join('C:/my-wiki/raw', '*.docx')))
for i, p in enumerate(paths):
    out = 'C:/my-wiki/_docx_%d.txt' % i
    text = extract(p)
    with open(out, 'w', encoding='utf-8') as f:
        f.write('SOURCE: ' + os.path.basename(p) + '\n\n' + text)
    print('written:', out, 'from', os.path.basename(p).encode('unicode_escape').decode(), 'chars=', len(text))
