import zipfile, re, sys

def extract(path):
    xml = zipfile.ZipFile(path).read('word/document.xml').decode('utf-8')
    # table cell / row / paragraph boundaries -> readable separators
    xml = xml.replace('</w:tc>', ' | ')
    xml = xml.replace('</w:tr>', '\n')
    xml = xml.replace('</w:p>', '\n')
    xml = xml.replace('<w:tab/>', '\t')
    xml = xml.replace('<w:br/>', '\n')
    text = re.sub(r'<[^>]+>', '', xml)
    text = re.sub(r'[ \t]*\|[ \t]*\n', '\n', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text

if __name__ == '__main__':
    path = sys.argv[1]
    text = extract(path)
    if len(sys.argv) > 2:
        # write to file via Python I/O (avoids blocked shell redirection)
        with open(sys.argv[2], 'w', encoding='utf-8') as f:
            f.write(text)
        print('written:', sys.argv[2], 'chars=', len(text))
    else:
        print(text)
