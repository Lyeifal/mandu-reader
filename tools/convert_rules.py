#!/usr/bin/env python3
"""so-novel 规则 -> 漫读书源的一次性转换器（M5）。

输入: D:\\Code\\github-project\\so-novel\\bundle\\rules\\*.json
输出: app/assets/rules/sources.json（平铺数组，sourceId/group/disabled 补齐，
      全部 @js:/@java: 链改写为 @op: 算子链）

转换映射原则：
- 通用模式（replace/replaceAll/regexReplace/prefix/url拼接）按正则改写；
- 特殊脚本（qsbs 解密/全本签名/JSONP/老幺排序/顶点隐藏li/96读书 nextpage）
  用精确字符串匹配断言后替换为具名算子，**脚本内容有变化会当场报错**，
  需人工核对后再补映射。
"""
import json
import re
import sys
from pathlib import Path

SO_NOVEL = Path(r'D:\Code\github-project\so-novel\bundle\rules')
OUT = Path(r'D:\Code\mandu_reader\app\assets\rules\sources.json')

GROUPS = ['main', 'proxy-required', 'rate-limit', 'no-search', 'cloudflare']

# slug: 稳定短名（域名主体），转换时按 url 分配
def slug_of(rule):
    host = re.sub(r'^https?://', '', rule['url']).split('/')[0]
    s = host.replace('www.', '').split('.')[0]
    return s

def js_replace_body(body):
    stmts = [s.strip() for s in body.split(';') if s.strip()]
    return ''.join(conv_stmt(s) for s in stmts)

def conv_stmt(st):
    # r='URL'+r  → @op:prefix('URL')
    m = re.fullmatch(r"r='([^']*)'\+r", st)
    if m:
        return f"@op:prefix('{m.group(1)}')"
    m = re.fullmatch(r'r="([^"]*)"\+r', st)
    if m:
        return f"@op:prefix(\"{m.group(1)}\")"
    # r=r.replaceAll('a','b')
    m = re.fullmatch(r"r=r\.replaceAll\('((?:[^'\\]|\\.)*)',\s*'((?:[^'\\]|\\.)*)'\)", st)
    if m:
        return f"@op:replaceAll('{unesc(m.group(1))}','{unesc(m.group(2))}')"
    # r=r.replace('a','b')  （字符串参数=首个）
    m = re.fullmatch(r"r=r\.replace\('((?:[^'\\]|\\.)*)',\s*'((?:[^'\\]|\\.)*)'\)", st)
    if m:
        return f"@op:replace('{unesc(m.group(1))}','{unesc(m.group(2))}')"
    # r=r.replace(/re/flags, 'rep')
    m = re.fullmatch(r"r=r\.replace\(/((?:[^/\\]|\\.)*)/(\w*),\s*'((?:[^'\\]|\\.)*)'\)", st)
    if m:
        return f"@op:regexReplace(/{m.group(1)}/{m.group(2)},'{unesc(m.group(3))}')"
    # r=r.match(/re/)[n]
    m = re.fullmatch(r"r=r\.match\(/((?:[^/\\]|\\.)*)/\w*\)\[(\d+)\]", st)
    if m:
        return f"@op:regexExtract(/{m.group(1)}/{m.group(2)})"
    raise AssertionError(f'无法转换的 JS 语句: {st!r}')

def unesc(s):
    # 规则里的 \' 还原为 '；\\ 还原为 \
    return s.replace("\\'", "'").replace('\\\\', '\\')

# —— 特殊整串替换（精确断言；内容漂移会直接报错）——
SPECIALS = [
    # 96读书 / 梦书：qsbs 提取 + base64（@java 链尾）
    ('#content@js:r=r.replace(/<script>\\s*document\\.writeln\\(qsbs\\.bb\\(\'([^\']+)\'\\)\\);\\s*<\\/script>/g,function(a,b){return b});@java:base64.decode()',
     '#content@op:qsbsExtract()@op:base64Lines()'),
    ('.row-detail > div > div@js:r=r.replace(/<script>\\s*document\\.writeln\\(qsbs\\.bb\\(\'([^\']+)\'\\)\\);\\s*<\\/script>/g,function(a,b){return b});@java:base64.decode()',
     '.row-detail > div > div@op:qsbsExtract()@op:base64Lines()'),
    # 96读书 nextpage：XPath + match
    ('//*[@id="readbg"]/script[4]@js:r=r.match(/nextpage = "(.*?)"/)[1];',
     '//*[@id="readbg"]/script[4]@op:regexExtract(/nextpage = "(.*?)"/,1)'),
    # 全本搜索签名：整串即插件（输入 keyword）
    ('@js:var s="PXhw7UT1B0a9kQDKZsjIASmOezxYG4CHo5Jyfg2b8FLpEvRr3WtVnlqMidu6cN";var kw=encodeURI(r);var e="";for(var i=0;i<kw.length;i++){var n=s.indexOf(kw[i]);var c=n==-1?kw[i]:s[(n+3)%62];var n1=parseInt(Math.random()*62,10);var n2=parseInt(Math.random()*62,10);e+=s[n1]+c+s[n2];}return \'https://quanben5.com/?c=book&a=search.json&callback=search&keywords=\'+r+\'&b=\'+encodeURI(e);',
     '@op:quanbenSearchUrl()'),
    # 全本 JSONP 拆包
    ('.pic_txt_list@js:var m=r.match(/search\\((.+)\\)/);if(!m)return r;var o=JSON.parse(m[1]);return o.content.replace(/\\r/g,\'\').replace(/\\n/g,\'\').replace(/\\t/g,\'\');',
     '.pic_txt_list@op:jsonpField(\'content\')@op:stripCtl()'),
    # 燃文内联 qsbs 全文
    ('#htmlContent@js:var qsbs={_keyStr:"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=",bb:function(input){var output="";var chr1,chr2,chr3;var enc1,enc2,enc3,enc4;var i=0;input=input.replace(/[^A-Za-z0-9\\+\\/\\=]/g,"");while(i<input.length){enc1=this._keyStr.indexOf(input.charAt(i++));enc2=this._keyStr.indexOf(input.charAt(i++));enc3=this._keyStr.indexOf(input.charAt(i++));enc4=this._keyStr.indexOf(input.charAt(i++));chr1=(enc1<<2)|(enc2>>4);chr2=((enc2&15)<<4)|(enc3>>2);chr3=((enc3&3)<<6)|enc4;output=output+String.fromCharCode(chr1);if(enc3!=64){output=output+String.fromCharCode(chr2)}if(enc4!=64){output=output+String.fromCharCode(chr3)}}output=qsbs._utf8_decode(output);return output},_utf8_encode:function(string){string=string.replace(/\\r\\n/g,"\\n");var utftext="";for(var n=0;n<string.length;n++){var c=string.charCodeAt(n);if(c<128){utftext+=String.fromCharCode(c)}else if((c>127)&&(c<2048)){utftext+=String.fromCharCode((c>>6)|192);utftext+=String.fromCharCode((c&63)|128)}else{utftext+=String.fromCharCode((c>>12)|224);utftext+=String.fromCharCode(((c>>6)&63)|128);utftext+=String.fromCharCode((c&63)|128)}}return utftext},_utf8_decode:function(utftext){var string="";var i=0,c1,c2,c3;var c=c1=c2=0;while(i<utftext.length){c=utftext.charCodeAt(i);if(c<128){string+=String.fromCharCode(c);i++}else if((c>191)&&(c<224)){c2=utftext.charCodeAt(i+1);string+=String.fromCharCode(((c&31)<<6)|(c2&63));i+=2}else{c2=utftext.charCodeAt(i+1);c3=utftext.charCodeAt(i+2);string+=String.fromCharCode(((c&15)<<12)|((c2&63)<<6)|(c3&63));i+=3}}return string}};r=r.replace(/<script>\\s*document\\.writeln\\(qsbs\\.bb\\(\'([^\']+)\'\\)\\);\\s*<\\/script>/g,function(match,p1){return qsbs.bb(p1)});',
     '#htmlContent@op:qsbsDecode()'),
    # 顶点：隐藏 li 过滤（整段 filterHiddenLis 插件）
    ('/html@js:const childRegex=/\\.section-list\\.ycxsid>li:nth-child\\(\\d+\\)\\{display:none\\}/g;const lastChildRegex=/\\.section-list\\.ycxsid>li:nth-last-child\\(\\d+\\)\\{display:none\\}/g;const preHiddenCount=[...r.matchAll(childRegex)].length;const afterHiddenCount=[...r.matchAll(lastChildRegex)].length;r=r.replace(/<ul[^>]*class="[^"]*\\bsection-list\\b[^"]*\\bycxsid\\b[^"]*"[^>]*>([\\s\\S]*?)<\\/ul>/g,(match,liContent)=>{const lis=liContent.match(/<li[\\s\\S]*?<\\/li>/g)||[];const newLis=lis.slice(preHiddenCount,lis.length-afterHiddenCount);return match.replace(liContent,newLis.join(\'\'))});',
     '/html@op:filterHiddenLis()'),
    # 老幺：dd data-id 排序
    ('#txt@js:const ddMatches=[...r.matchAll(/<dd\\s+data-id="(\\d+)">([\\s\\S]*?)<\\/dd>/g)];const ddList=ddMatches.map(match=>({id:Number(match[1]),content:match[2]}));ddList.sort((a,b)=>a.id-b.id);let result=\'\';for(const dd of ddList){const pMatches=[...dd.content.matchAll(/<p>[\\s\\S]*?<\\/p>/g)];pMatches.forEach(p=>{result+=p[0]})}r=result;',
     '#txt@op:ddSortByDataId()'),
]

CF_SLUGS = {'xhytd', '96dushu', 'dongtanxs'}

# 2026-10-04 全量巡检（dart run tool/source_doctor.dart，5/22 通过）结果固化：
# 死源/失效源默认禁用并带原因；需代理源本机无代理亦禁用（配置后可手动开）。
# 重跑本脚本不会丢这些标注——上游复活/修好规则时从这里删条目即可。
DOCTOR_DISABLED = {
    # 巡检实锤失败
    'xbiqugu': '域名解析失败（站已下线）2026-10-04 巡检',
    'shuhaige': '连接被拒（反爬或已下线）2026-10-04 巡检',
    '22biqu': '搜索页 404（站结构改版）2026-10-04 巡检',
    'wxsy': '搜索 403（被禁）2026-10-04 巡检',
    'biquge365': '搜索无结果（规则可能失效）2026-10-04 巡检',
    'ranwen8': 'TLS 握手失败（站异常）2026-10-04 巡检',
    'tianxibook': '搜索无结果（规则可能失效）2026-10-04 巡检',
    '0xs': '目录为空（目录选择器失效）2026-10-04 巡检',
    'laoyaoxs': '请求超时（站慢或已下线）2026-10-04 巡检',
    'sudugu': 'TLS 握手失败（站异常）2026-10-04 巡检',
    # 需代理源：本机未配置 source.proxy，未实测不可用
    '69shuba': '需代理（本机未配置 source.proxy）',
    'quanben5': '需代理（本机未配置 source.proxy）',
    'dxmwx': '需代理（本机未配置 source.proxy）',
    '101kks': '需代理（本机未配置 source.proxy）',
}

def transform(value):
    if not isinstance(value, str) or '@js:' not in value:
        return value
    # 前缀断言类长脚本（逐字誊抄易错，按特征前缀识别）
    if value.startswith('/html@js:const childRegex='):
        return '/html@op:filterHiddenLis()'
    if value.startswith('#txt@js:const ddMatches='):
        return '#txt@op:ddSortByDataId()'
    if value.startswith('#htmlContent@js:var qsbs='):
        return '#htmlContent@op:qsbsDecode()'
    if value.startswith('@js:var s="PXhw7UT1B0a9'):
        return '@op:quanbenSearchUrl()'
    if value.startswith('.pic_txt_list@js:var m=r.match(/search'):
        return '.pic_txt_list@op:jsonpField(\'content\')@op:stripCtl()'
    if value.startswith('//*[@id="readbg"]/script[4]@js:'):
        return '//*[@id="readbg"]/script[4]@op:regexExtract(/nextpage = "(.*?)"/,1)'
    for old, new in SPECIALS:
        if value == old:
            return new
    # 通用改写：拆出 @java 尾，@js 体按语句转换
    out = value
    java_tail = ''
    if '@java:' in out:
        before, _, tail = out.partition('@java:')
        out = before
        java_tail = '@java:' + tail
    i = out.find('@js:')
    body = out[i + 4 :].rstrip()
    if body.endswith(';'):
        body = body[:-1]
    out = out[:i] + js_replace_body(body)
    if java_tail:
        out += java_tail.replace('@java:base64.decode()', '@op:base64Lines()')
    if '@js:' in out:
        raise AssertionError(f'转换后仍残留 @js: {out!r}')
    if '@java:' in out:
        raise AssertionError(f'转换后仍残留 @java: {out!r}')
    return out

def js_replace_body(body):
    stmts = [s.strip() for s in body.split(';') if s.strip()]
    return ''.join(conv_stmt(s) for s in stmts)

def walk(obj):
    if isinstance(obj, dict):
        return {k: walk(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [walk(v) for v in obj]
    return transform(obj)

def main():
    out_rules = []
    seen = set()
    for group in GROUPS:
        path = SO_NOVEL / f'{group}.json'
        for rule in json.load(open(path, encoding='utf-8')):
            slug = slug_of(rule)
            assert slug not in seen, f'slug 冲突: {slug}'
            seen.add(slug)
            r = walk(rule)
            r['sourceId'] = slug
            r['group'] = group
            if slug in CF_SLUGS:
                r['disabled'] = True
                r['disableReason'] = 'cf_challenge_risk'
            elif slug in DOCTOR_DISABLED:
                r['disabled'] = True
                r['disableReason'] = DOCTOR_DISABLED[slug]
            out_rules.append(r)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(out_rules, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'OK: {len(out_rules)} 源 -> {OUT}')
    print('disabled:', [r['sourceId'] for r in out_rules if r.get('disabled')])

if __name__ == '__main__':
    main()
