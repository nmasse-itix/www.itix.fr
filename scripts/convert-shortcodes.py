#!/usr/bin/env python3
"""
Converts the custom shortcodes of www.itix.fr to standard Markdown syntax,
rendered by the render hooks in layouts/_markup.

  {{< attachedFigure src="x.png" title="Caption" >}}  ->  ![Caption](x.png "Caption")
  {{< screenshotOf src="tweet-x.png" href="URL" >}}    ->  [![Tweet by @x](tweet-x.png)](URL)
  [text]({{< attachedFileLink src="x.pdf" >}})         ->  [text](x.pdf)
                                                       (kept as-is outside of a Markdown link)
  [text]({{< relref "/blog/x" >}})                     ->  [text](/blog/x)
  {{< internalLink path="/blog/x.md" >}}               ->  [](/blog/x.md)
  {{< internalLink path="/blog/x.md" title="T" >}}     ->  [T](/blog/x.md)
  {{< highlightFile "f.yaml" "yaml" "hl_lines=3" >}}   ->  ```yaml {filename="f.yaml" hl_lines="3"}
  {{< highlightWithTitle "T" "sh" "" >}}               ->  ```sh {title="T"}
  {{< highlight yaml "hl_lines=5" >}}                  ->  ```yaml {hl_lines="5"}

Usage: scripts/convert-shortcodes.py FILE.md [FILE.md...]
"""

import re
import sys


def parse_args(args):
    """Parses shortcode arguments: named (key="value") or positional."""
    named, positional = {}, []
    for m in re.finditer(r'(\w+)="((?:[^"\\]|\\.)*)"|"((?:[^"\\]|\\.)*)"|(\S+)', args):
        if m.group(1):
            named[m.group(1)] = m.group(2).replace('\\"', '"')
        elif m.group(3) is not None:
            positional.append(m.group(3).replace('\\"', '"'))
        else:
            positional.append(m.group(4))
    return named, positional


def plain(text):
    """Strips the Markdown formatting of a caption, to be used as alt text."""
    text = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', text)
    text = re.sub(r'[`*_]', '', text)
    return text.strip()


def md_title(text):
    return '"%s"' % text.replace('\\', '\\\\').replace('"', '\\"')


def md_alt(text):
    return text.replace('[', '\\[').replace(']', '\\]')


def fence_attrs(options):
    """Converts Hugo highlight options ("hl_lines=3 5-7,linenos=true") to fence attributes."""
    attrs = []
    for opt in re.split(r',\s*', options or ''):
        if '=' not in opt:
            continue
        key, value = opt.split('=', 1)
        if value.strip():
            attrs.append('%s=%s' % (key.strip(), md_title(value.strip())))
    return attrs


def fence(lang, attrs, inner):
    inner = inner.strip('\n')
    ticks = '```'
    while ticks in inner:
        ticks += '`'
    info = lang + (' {%s}' % ' '.join(attrs) if attrs else '')
    return '%s%s\n%s\n%s' % (ticks, info, inner, ticks)


def standalone(match, replacement):
    """Ensures a block-level element (figure) is separated by blank lines."""
    s, start, end = match.string, match.start(), match.end()
    before = '' if start == 0 or s[:start].endswith('\n\n') else ('\n' if s[:start].endswith('\n') else '\n\n')
    after = '' if end == len(s) or s[end:].startswith('\n\n') else ('\n' if s[end:].startswith('\n') else '\n\n')
    return before + replacement + after


def convert(text, lang):
    # Code blocks
    def code(m):
        name, args, inner = m.group(1), m.group(2), m.group(3)
        named, pos = parse_args(args)
        if name == 'highlightFile':
            return fence(pos[1], ['filename=%s' % md_title(pos[0])] + fence_attrs(pos[2] if len(pos) > 2 else ''), inner)
        if name == 'highlightWithTitle':
            return fence(pos[1], ['title=%s' % md_title(pos[0])] + fence_attrs(pos[2] if len(pos) > 2 else ''), inner)
        return fence(pos[0], fence_attrs(pos[1] if len(pos) > 1 else ''), inner)

    text = re.sub(r'\{\{<\s*(highlightFile|highlightWithTitle|highlight)\s+(.*?)\s*>\}\}(.*?)\{\{<\s*/\s*\1\s*>\}\}',
                  code, text, flags=re.S)

    # Figures
    def figure(m):
        named, _ = parse_args(m.group(1))
        title = named.get('title', '')
        img = '![%s](%s%s)' % (md_alt(plain(title)), named['src'], ' ' + md_title(title) if title else '')
        return standalone(m, img)

    text = re.sub(r'\{\{<\s*attachedFigure\s+(.*?)\s*>\}\}', figure, text)
    # Only one blank line between consecutive figures
    text = re.sub(r'(!\[[^\n]*\))\n{3,}(?=!\[)', r'\1\n\n', text)

    # Screenshots of tweets, linked to the tweet
    def screenshot(m):
        named, _ = parse_args(m.group(1))
        handle = re.sub(r'^tweet-|(-\d+)?\.\w+$', '', named['src'])
        alt = ('Tweet de @%s' if lang == 'fr' else 'Tweet by @%s') % handle
        return '[![%s](%s)](%s)' % (alt, named['src'], named['href'])

    text = re.sub(r'\{\{<\s*screenshotOf\s+(.*?)\s*>\}\}', screenshot, text)

    # Links
    # (attachedFileLink is kept when used elsewhere, e.g. in code blocks)
    text = re.sub(r'\]\(\{\{<\s*attachedFileLink\s+src="([^"]+)"\s*>\}\}\)', r'](\1)', text)
    text = re.sub(r'\{\{<\s*relref\s+"([^"]+)"\s*>\}\}', r'\1', text)

    def internal_link(m):
        named, _ = parse_args(m.group(1))
        return '[%s](%s)' % (named.get('title', ''), named['path'])

    text = re.sub(r'\{\{<\s*internalLink\s+(.*?)\s*>\}\}', internal_link, text)
    return text


for filename in sys.argv[1:]:
    with open(filename, encoding='utf-8') as f:
        original = f.read()
    converted = convert(original, 'fr' if '/french/' in filename else 'en')
    if converted != original:
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(converted)
        print('converted:', filename)
