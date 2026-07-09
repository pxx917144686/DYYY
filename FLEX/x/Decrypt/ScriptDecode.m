#import "ScriptDecode.h"
#import "DYYYDatabaseManager.h"

extern NSString *CurrentBundleID(void);

static NSString *IZXTrim(NSString *s) {
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
}

static BOOL IZXContains(NSString *s, NSString *needle) {
    return [s rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static NSData *IZXDataFromHexString(NSString *hex) {
    NSString *compact = [[hex componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
    compact = [[compact stringByReplacingOccurrencesOfString:@"0x" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, compact.length)] stringByReplacingOccurrencesOfString:@"\\x" withString:@""];
    if (compact.length < 2 || compact.length % 2 != 0) return nil;
    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    if ([compact rangeOfCharacterFromSet:hexSet.invertedSet].location != NSNotFound) return nil;
    NSMutableData *data = [NSMutableData dataWithCapacity:compact.length / 2];
    for (NSUInteger i = 0; i < compact.length; i += 2) {
        unsigned int value = 0;
        NSString *part = [compact substringWithRange:NSMakeRange(i, 2)];
        NSScanner *scanner = [NSScanner scannerWithString:part];
        if (![scanner scanHexInt:&value]) return nil;
        uint8_t byte = (uint8_t)value;
        [data appendBytes:&byte length:1];
    }
    return data;
}

static NSString *IZXDecodeEscapes(NSString *input) {
    if (input.length == 0) return @"";
    NSMutableString *out = [NSMutableString stringWithCapacity:input.length];
    NSUInteger i = 0;
    while (i < input.length) {
        unichar c = [input characterAtIndex:i];
        if (c == '\\' && i + 1 < input.length) {
            unichar n = [input characterAtIndex:i + 1];
            if ((n == 'x' || n == 'X') && i + 3 < input.length) {
                NSString *hex = [input substringWithRange:NSMakeRange(i + 2, 2)];
                unsigned int value = 0;
                if ([[NSScanner scannerWithString:hex] scanHexInt:&value]) {
                    [out appendFormat:@"%C", (unichar)value];
                    i += 4;
                    continue;
                }
            } else if ((n == 'u' || n == 'U') && i + 5 < input.length) {
                NSString *hex = [input substringWithRange:NSMakeRange(i + 2, 4)];
                unsigned int value = 0;
                if ([[NSScanner scannerWithString:hex] scanHexInt:&value]) {
                    [out appendFormat:@"%C", (unichar)value];
                    i += 6;
                    continue;
                }
            } else if (n == 'n') { [out appendString:@"\n"]; i += 2; continue; }
            else if (n == 'r') { [out appendString:@"\r"]; i += 2; continue; }
            else if (n == 't') { [out appendString:@"\t"]; i += 2; continue; }
        }
        [out appendFormat:@"%C", c];
        i++;
    }
    return out;
}

static NSArray<NSString *> *IZXRegexCaptures(NSString *text, NSString *pattern) {
    if (text.length == 0 || pattern.length == 0) return @[];
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionDotMatchesLineSeparators error:&error];
    if (error || !regex) return @[];
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    for (NSTextCheckingResult *m in matches) {
        if (m.numberOfRanges > 1) {
            NSRange r = [m rangeAtIndex:1];
            if (r.location != NSNotFound && NSMaxRange(r) <= text.length) [items addObject:[text substringWithRange:r]];
        }
    }
    return items;
}

static BOOL IZXIsAAEncode(NSString *script);
static BOOL IZXIsJSFuck(NSString *script);

NSString *IZXScriptDetectType(NSString *script) {
    NSString *s = script ?: @"";
    if (s.length == 0) return @"empty";
    if (IZXIsAAEncode(s)) return @"aaencode";
    if (IZXIsJSFuck(s)) return @"jsfuck";
    if (IZXContains(s, @"function(p,a,c,k,e,d)")) return @"packer";
    if (IZXContains(s, @"jsjiami.com.v7") || IZXContains(s, @"sojson.v7") || IZXContains(s, @"jsjiami.v7")) return @"sojsonv7";
    if (IZXContains(s, @"jsjiami.com.v6") || IZXContains(s, @"sojson.v6") || IZXContains(s, @"jsjiami.v6")) return @"sojson";
    if (IZXContains(s, @"awsc") || IZXContains(s, @"_uab_collina") || IZXContains(s, @"umidToken") || IZXContains(s, @"aliyun") || IZXContains(s, @"__acjs_awsc")) return @"awsc";
    if (IZXContains(s, @"$=~[]") || IZXContains(s, @"$$=~[]") || IZXContains(s, @"$_=$") || IZXContains(s, @"jjencode")) return @"jjencode";
    if (IZXContains(s, @"javascript-obfuscator") || IZXContains(s, @"while(!![])") || IZXContains(s, @"stringArray") || IZXContains(s, @"controlFlowFlattening")) return @"obfuscator";
    if (IZXContains(s, @"eval(function(p,a,c,k,e,d)") || IZXContains(s, @"atob(") || IZXContains(s, @"fromCharCode") || IZXContains(s, @"unescape(") || IZXContains(s, @"base64.b64decode")) return @"common";
    if (IZXContains(s, @"_0x") && IZXContains(s, @"function")) return @"obfuscator/common";
    return @"common";
}

static NSString *IZXDecodeBase64Literals(NSString *script) {
    NSMutableArray<NSString *> *decodedBlocks = [NSMutableArray array];
    NSArray<NSString *> *patterns = @[
        @"atob\\s*\\(\\s*['\\\"]([A-Za-z0-9+/_=-]{12,})['\\\"]\\s*\\)",
        @"base64\\.b64decode\\s*\\(\\s*['\\\"]([A-Za-z0-9+/_=-]{12,})['\\\"]\\s*\\)",
        @"Buffer\\.from\\s*\\(\\s*['\\\"]([A-Za-z0-9+/_=-]{12,})['\\\"]\\s*,\\s*['\\\"]base64['\\\"]"
    ];
    for (NSString *pattern in patterns) {
        for (NSString *raw in IZXRegexCaptures(script, pattern)) {
            NSString *b64 = [[raw stringByReplacingOccurrencesOfString:@"-" withString:@"+"] stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
            NSUInteger mod = b64.length % 4;
            if (mod) b64 = [b64 stringByPaddingToLength:b64.length + (4 - mod) withString:@"=" startingAtIndex:0];
            NSData *data = [[NSData alloc] initWithBase64EncodedString:b64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
            NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (text.length && ![decodedBlocks containsObject:text]) [decodedBlocks addObject:text];
        }
    }
    if (decodedBlocks.count == 0) return nil;
    return [decodedBlocks componentsJoinedByString:@"\n\n/* ---- base64 block ---- */\n\n"];
}

static NSString *IZXDecodeStringFromCharCode(NSString *script) {
    NSArray<NSString *> *items = IZXRegexCaptures(script, @"String\\.fromCharCode\\s*\\(([^\\)]{5,})\\)");
    NSMutableArray<NSString *> *outputs = [NSMutableArray array];
    for (NSString *item in items) {
        NSArray<NSString *> *parts = [item componentsSeparatedByString:@","];
        NSMutableString *s = [NSMutableString string];
        for (NSString *part in parts) {
            NSString *p = IZXTrim(part);
            NSInteger value = 0;
            if ([p hasPrefix:@"0x"] || [p hasPrefix:@"0X"]) {
                unsigned int v = 0;
                if (![[NSScanner scannerWithString:p] scanHexInt:&v]) continue;
                value = (NSInteger)v;
            } else {
                value = p.integerValue;
            }
            if (value > 0 && value <= 0xFFFF) [s appendFormat:@"%C", (unichar)value];
        }
        if (s.length && ![outputs containsObject:s]) [outputs addObject:s];
    }
    if (outputs.count == 0) return nil;
    return [outputs componentsJoinedByString:@"\n\n/* ---- fromCharCode block ---- */\n\n"];
}

static NSString *IZXDecodeHexEscapedStrings(NSString *script) {
    if (![script containsString:@"\\x"] && ![script containsString:@"\\u"]) return nil;
    NSString *decoded = IZXDecodeEscapes(script);
    return [decoded isEqualToString:script] ? nil : decoded;
}

static NSString *IZXDecodePercentEncoded(NSString *script) {
    if (![script containsString:@"%"] && !IZXContains(script, @"unescape(")) return nil;
    NSString *decoded = [script stringByRemovingPercentEncoding];
    if (decoded.length && ![decoded isEqualToString:script]) return decoded;
    NSArray<NSString *> *items = IZXRegexCaptures(script, @"unescape\\s*\\(\\s*['\\\"]([^'\\\"]{6,})['\\\"]\\s*\\)");
    NSMutableArray<NSString *> *outs = [NSMutableArray array];
    for (NSString *item in items) {
        NSString *d = [item stringByRemovingPercentEncoding];
        if (d.length && ![outs containsObject:d]) [outs addObject:d];
    }
    return outs.count ? [outs componentsJoinedByString:@"\n\n/* ---- unescape block ---- */\n\n"] : nil;
}

static NSString *IZXDecodeHexBlob(NSString *script) {
    NSArray<NSString *> *items = IZXRegexCaptures(script, @"['\\\"]([0-9a-fA-F]{32,})['\\\"]");
    NSMutableArray<NSString *> *outs = [NSMutableArray array];
    for (NSString *hex in items) {
        NSData *data = IZXDataFromHexString(hex);
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (text.length && ![outs containsObject:text]) [outs addObject:text];
    }
    return outs.count ? [outs componentsJoinedByString:@"\n\n/* ---- hex block ---- */\n\n"] : nil;
}

static NSString *IZXLightFormatForObfuscatedJS(NSString *script) {
    NSString *s = script ?: @"";
    NSArray<NSString *> *tokens = @[@";", @"{", @"}"];
    NSArray<NSString *> *repls = @[@";\n", @"{\n", @"}\n"];
    for (NSUInteger i = 0; i < tokens.count; i++) {
        s = [s stringByReplacingOccurrencesOfString:tokens[i] withString:repls[i]];
    }
    while ([s containsString:@"\n\n\n"]) s = [s stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
    return s;
}

static NSString *IZXBaseEncode(NSUInteger num, NSUInteger base) {
    if (num == 0) return @"0";
    NSString *chars = @"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    NSMutableString *result = [NSMutableString string];
    while (num > 0) {
        NSUInteger remainder = num % base;
        if (remainder < 62) {
            [result insertString:[chars substringWithRange:NSMakeRange(remainder, 1)] atIndex:0];
        }
        num /= base;
    }
    return result;
}

static NSString *IZXUnescapeJSString(NSString *s) {
    if (!s) return @"";
    s = [s stringByReplacingOccurrencesOfString:@"\\'" withString:@"'"];
    s = [s stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
    s = [s stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
    s = [s stringByReplacingOccurrencesOfString:@"\\r" withString:@"\r"];
    s = [s stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
    s = [s stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
    s = [s stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    return s;
}

static NSString *IZXDecodePacker(NSString *script) {
    if (!script || ![script containsString:@"function(p,a,c,k,e,d)"]) return nil;

    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:
                                  @"\\}\\s*\\(\\s*'([\\s\\S]*?)'\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*'([\\s\\S]*?)'\\s*\\.split"
                                  options:0 error:&error];
    if (error || !regex) return nil;

    NSTextCheckingResult *match = [regex firstMatchInString:script options:0 range:NSMakeRange(0, script.length)];
    if (!match || match.numberOfRanges < 5) return nil;

    NSString *payload = [script substringWithRange:[match rangeAtIndex:1]];
    NSUInteger base = [[script substringWithRange:[match rangeAtIndex:2]] integerValue];
    NSUInteger count = [[script substringWithRange:[match rangeAtIndex:3]] integerValue];
    NSString *wordsStr = [script substringWithRange:[match rangeAtIndex:4]];
    NSArray<NSString *> *words = [wordsStr componentsSeparatedByString:@"|"];

    if (base < 2 || count == 0 || words.count == 0) return nil;

    payload = IZXUnescapeJSString(payload);
    NSMutableString *result = [payload mutableCopy];

    for (NSInteger i = (NSInteger)count - 1; i >= 0; i--) {
        if (i >= (NSInteger)words.count) continue;
        NSString *token = IZXBaseEncode((NSUInteger)i, base);
        NSString *word = words[i];
        if (word.length == 0 || [word isEqualToString:token]) continue;

        NSString *pattern = [NSString stringWithFormat:@"\\b%@\\b",
                            [NSRegularExpression escapedPatternForString:token]];
        NSRegularExpression *tokenRegex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        if (!tokenRegex) continue;

        NSArray<NSTextCheckingResult *> *matches = [tokenRegex matchesInString:result options:0 range:NSMakeRange(0, result.length)];
        for (NSInteger j = (NSInteger)matches.count - 1; j >= 0; j--) {
            NSRange r = [matches[j] range];
            [result replaceCharactersInRange:r withString:word];
        }
    }

    return result.length > 0 ? result : nil;
}

static NSString *IZXStripEvalWrapper(NSString *script) {
    if (!script) return nil;
    NSString *s = IZXTrim(script);
    if (s.length < 8) return nil;

    if ([s hasPrefix:@"eval("] && [s hasSuffix:@")"]) {
        NSString *inner = IZXTrim([s substringWithRange:NSMakeRange(5, s.length - 6)]);
        if (inner.length >= 2) {
            unichar first = [inner characterAtIndex:0];
            unichar last = [inner characterAtIndex:inner.length - 1];
            if ((first == '\'' && last == '\'') || (first == '"' && last == '"')) {
                NSString *content = [inner substringWithRange:NSMakeRange(1, inner.length - 2)];
                content = IZXUnescapeJSString(content);
                if (content.length > 0) return content;
            }

            if ([inner hasPrefix:@"decodeURIComponent("]) {
                NSString *sub = IZXTrim([inner substringWithRange:NSMakeRange(19, inner.length - 20)]);
                if (sub.length >= 2) {
                    unichar f = [sub characterAtIndex:0];
                    unichar l = [sub characterAtIndex:sub.length - 1];
                    if ((f == '\'' && l == '\'') || (f == '"' && l == '"')) {
                        NSString *encoded = [sub substringWithRange:NSMakeRange(1, sub.length - 2)];
                        NSString *decoded = [encoded stringByRemovingPercentEncoding];
                        if (decoded.length) return decoded;
                    }
                }
            }
        }
    }
    return nil;
}

static NSString *IZXDecodeDocumentWriteUnescape(NSString *script) {
    if (!script || ![script containsString:@"document.write"]) return nil;
    NSArray<NSString *> *items = IZXRegexCaptures(script, @"document\\.write\\s*\\(\\s*unescape\\s*\\(\\s*['\\\"]([^'\\\"]+)['\\\"]\\s*\\)\\s*\\)");
    if (items.count == 0) return nil;
    NSMutableArray<NSString *> *outs = [NSMutableArray array];
    for (NSString *item in items) {
        NSString *decoded = [item stringByRemovingPercentEncoding];
        if (decoded.length && ![outs containsObject:decoded]) [outs addObject:decoded];
    }
    return outs.count ? [outs componentsJoinedByString:@"\n\n"] : nil;
}

static BOOL IZXIsAAEncode(NSString *script) {
    if (!script || script.length < 20) return NO;

    return [script containsString:@"ﾟωﾟ"] || [script containsString:@"ﾟДﾟ"] || [script containsString:@"ﾟΘﾟ"];
}

static BOOL IZXIsJSFuck(NSString *script) {
    if (!script || script.length < 30) return NO;
    NSString *s = [[script componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];

    NSCharacterSet *jsfuckSet = [NSCharacterSet characterSetWithCharactersInString:@"[]()!+"];
    NSUInteger nonJSFuck = 0;
    NSUInteger checkLen = MIN(s.length, (NSUInteger)2000);
    for (NSUInteger i = 0; i < checkLen; i++) {
        if (![jsfuckSet characterIsMember:[s characterAtIndex:i]]) {
            nonJSFuck++;
            if (nonJSFuck > checkLen * 5 / 100) return NO;
        }
    }
    return YES;
}

NSString *IZXDecodeScriptText(NSString *script, NSString *source) {
    NSString *input = script ?: @"";
    if (input.length < 8) return nil;
    NSString *type = IZXScriptDetectType(input);
    NSMutableArray<NSString *> *sections = [NSMutableArray array];

    NSString *packerDecoded = IZXDecodePacker(input);
    if (packerDecoded.length) {
        [sections addObject:[@"[p-a-c-k-e-r 完整解码]\n" stringByAppendingString:packerDecoded]];

        NSString *innerType = IZXScriptDetectType(packerDecoded);
        if (![innerType isEqualToString:@"common"] && ![innerType isEqualToString:@"empty"]) {
            NSString *recursive = IZXDecodeScriptText(packerDecoded, [NSString stringWithFormat:@"%@ (packer递归)", source ?: @""]);
            if (recursive.length) [sections addObject:[@"[p-a-c-k-e-r 递归二次解码]\n" stringByAppendingString:recursive]];
        }
    }

    NSString *evalStripped = IZXStripEvalWrapper(input);
    if (evalStripped.length && ![evalStripped isEqualToString:input]) {
        [sections addObject:[@"[eval() 包装器剥离]\n" stringByAppendingString:evalStripped]];

        NSString *innerDecoded = IZXDecodeScriptText(evalStripped, [NSString stringWithFormat:@"%@ (eval递归)", source ?: @""]);
        if (innerDecoded.length) [sections addObject:[@"[eval 递归解码]\n" stringByAppendingString:innerDecoded]];
    }

    NSString *docWrite = IZXDecodeDocumentWriteUnescape(input);
    if (docWrite.length) [sections addObject:[@"[document.write(unescape) 解码]\n" stringByAppendingString:docWrite]];

    NSString *base64 = IZXDecodeBase64Literals(input);
    if (base64.length) [sections addObject:[@"[Base64/atob/base64.b64decode 解码]\n" stringByAppendingString:base64]];

    NSString *fromChar = IZXDecodeStringFromCharCode(input);
    if (fromChar.length) [sections addObject:[@"[String.fromCharCode 解码]\n" stringByAppendingString:fromChar]];

    NSString *percent = IZXDecodePercentEncoded(input);
    if (percent.length) [sections addObject:[@"[URL/unescape 解码]\n" stringByAppendingString:percent]];

    NSString *hexBlob = IZXDecodeHexBlob(input);
    if (hexBlob.length) [sections addObject:[@"[Hex 字符串解码]\n" stringByAppendingString:hexBlob]];

    NSString *escapes = IZXDecodeHexEscapedStrings(input);
    if (escapes.length) [sections addObject:[@"[\\x/\\u 字符串还原]\n" stringByAppendingString:escapes]];

    if ([type isEqualToString:@"aaencode"]) {
        [sections addObject:@"[AAEncode 检测]\n检测到 AAEncode (顔文字编码)，该类型需要 JavaScript 引擎执行解码，App 内无法完全还原。\n特征: 大量 ﾟωﾟ ﾟДﾟ 等日文半角字符。"];
    }
    if ([type isEqualToString:@"jsfuck"]) {
        [sections addObject:@"[JSFuck 检测]\n检测到 JSFuck 编码，该类型仅使用 []()!+ 六个字符表示任意 JavaScript，需要 JS 引擎执行解码。\n特征: 代码仅包含 []()!+ 字符。"];
    }

    BOOL knownObfuscation = ![type isEqualToString:@"common"] || IZXContains(input, @"eval(") || IZXContains(input, @"_0x");
    if (knownObfuscation) {
        NSString *formatted = IZXLightFormatForObfuscatedJS(input);
        if (formatted.length && ![formatted isEqualToString:input]) {
            NSUInteger maxLen = MIN((NSUInteger)60000, formatted.length);
            NSString *preview = [formatted substringToIndex:maxLen];
            [sections addObject:[@"[轻量格式化/结构展开]\n" stringByAppendingString:preview]];
        }
    }

    if (sections.count == 0) return nil;
    NSString *joined = [sections componentsJoinedByString:@"\n\n==============================\n\n"];
    return [NSString stringWithFormat:@"[脚本自适应检测解密]\n来源: %@\n检测类型: %@\n支持类型: packer(p-a-c-k-e-r) / sojson(jsjiami.v6) / sojsonv7(jsjiami.v7) / obfuscator / awsc / jjencode / aaencode / jsfuck / common\n说明: App 内置轻量检测和常见字符串/编码解码；完整 AST 版 decode-main 已随源码包附带，可在电脑 Node 环境运行。\n\n%@", source ?: @"(unknown)", type, joined];
}

void IZXTryRecordDecodedScript(NSString *script, NSString *source) {
    NSString *decoded = IZXDecodeScriptText(script, source);
    if (decoded.length == 0) return;
    [[DYYYDatabaseManager sharedManager] insertDataIntoTable:@"decrypt_data" bundleID:CurrentBundleID() text:decoded];
    [[DYYYDatabaseManager sharedManager] insertLogText:[NSString stringWithFormat:@"脚本自适应检测完成: %@", IZXScriptDetectType(script ?: @"")]];
}
