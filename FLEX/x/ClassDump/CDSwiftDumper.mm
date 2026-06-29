#import "CDSwiftDumper.h"
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <dlfcn.h>
#import <cxxabi.h>

typedef char *(*SwiftDemangleFunc)(const char *mangledName,
                                   size_t mangledNameLength,
                                   char *outputBuffer,
                                   size_t *outputBufferSize,
                                   uint32_t flags);

static NSString *CDSafeName(NSString *name) {
    NSMutableString *s = [name mutableCopy] ?: [NSMutableString stringWithString:@"Unknown"];
    NSArray *bad = @[@"/", @":", @"*", @"?", @"\"", @"<", @">", @"|", @"\\", @" ", @"(", @")", @"[", @"]", @"{", @"}", @","];
    for (NSString *b in bad) {
        [s replaceOccurrencesOfString:b withString:@"_" options:0 range:NSMakeRange(0, s.length)];
    }
    while ([s containsString:@"__"]) {
        [s replaceOccurrencesOfString:@"__" withString:@"_" options:0 range:NSMakeRange(0, s.length)];
    }
    if (s.length > 180) {
        s = [[s substringToIndex:180] mutableCopy];
    }
    return s.length ? s : @"Unknown";
}

static BOOL CDShouldSkipImage(NSString *imagePath) {
    if (imagePath.length == 0) return YES;
    if ([imagePath hasPrefix:@"/System/"]) return YES;
    if ([imagePath hasPrefix:@"/usr/lib/"]) return YES;

    NSString *bundlePath = NSBundle.mainBundle.bundlePath ?: @"";
    NSString *container = [bundlePath stringByDeletingLastPathComponent];

    if ([imagePath hasPrefix:bundlePath]) return NO;
    if ([imagePath hasPrefix:container] && ([imagePath containsString:@"/Frameworks/"] ||
                                            [imagePath containsString:@"/PlugIns/"] ||
                                            [imagePath containsString:@"/Extensions/"])) {
        return NO;
    }
    return YES;
}

static SwiftDemangleFunc CDGetSwiftDemangle(void) {
    static SwiftDemangleFunc fn = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fn = (SwiftDemangleFunc)dlsym(RTLD_DEFAULT, "swift_demangle");
        if (!fn) {
            void *h = dlopen("/usr/lib/swift/libswiftCore.dylib", RTLD_NOW);
            if (h) fn = (SwiftDemangleFunc)dlsym(h, "swift_demangle");
        }
    });
    return fn;
}

static NSString *CDDemangleSwift(NSString *symbol) {
    if (symbol.length == 0) return nil;

    NSString *s = symbol;
    if ([s hasPrefix:@"_"]) s = [s substringFromIndex:1];

    if (![s hasPrefix:@"$s"] && ![s hasPrefix:@"$S"] && ![s hasPrefix:@"_$s"] && ![s hasPrefix:@"_$S"]) {
        return nil;
    }

    SwiftDemangleFunc demangle = CDGetSwiftDemangle();
    if (!demangle) return nil;

    const char *mangled = s.UTF8String;
    char *out = demangle(mangled, strlen(mangled), NULL, NULL, 0);
    if (!out) return nil;

    NSString *ret = [NSString stringWithUTF8String:out];
    free(out);

    if (ret.length == 0) return nil;
    if ([ret containsString:@"type metadata accessor"]) return nil;
    if ([ret containsString:@"nominal type descriptor"]) return nil;
    if ([ret containsString:@"reflection metadata"]) return nil;
    if ([ret containsString:@"associated type descriptor"]) return nil;
    if ([ret containsString:@"protocol conformance descriptor"]) return nil;
    if ([ret containsString:@"method lookup function"]) return nil;
    if ([ret containsString:@"outlined "]) return nil;
    if ([ret containsString:@"merged "]) return nil;
    if ([ret containsString:@"block_copy_helper"]) return nil;
    if ([ret containsString:@"block_destroy_helper"]) return nil;

    return ret;
}

static BOOL CDLooksLikeSwiftSymbol(NSString *name) {
    if (name.length == 0) return NO;
    return [name hasPrefix:@"_$s"] || [name hasPrefix:@"$s"] || [name hasPrefix:@"_$S"] || [name hasPrefix:@"$S"];
}

static NSArray<NSString *> *CDSwiftSymbolsForImage(const struct mach_header *mh) {
    NSMutableArray<NSString *> *symbols = [NSMutableArray array];

    BOOL is64 = (mh->magic == MH_MAGIC_64 || mh->magic == MH_CIGAM_64);
    if (!is64) return symbols;

    const struct mach_header_64 *header = (const struct mach_header_64 *)mh;
    const uint8_t *cursor = (const uint8_t *)(header + 1);

    const struct symtab_command *symtab = NULL;
    const struct segment_command_64 *linkedit = NULL;

    for (uint32_t i = 0; i < header->ncmds; i++) {
        const struct load_command *lc = (const struct load_command *)cursor;

        if (lc->cmd == LC_SYMTAB) {
            symtab = (const struct symtab_command *)lc;
        } else if (lc->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;
            if (strncmp(seg->segname, SEG_LINKEDIT, 16) == 0) {
                linkedit = seg;
            }
        }

        cursor += lc->cmdsize;
    }

    if (!symtab || !linkedit) return symbols;

    intptr_t slide = 0;
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        if (_dyld_get_image_header(i) == mh) {
            slide = _dyld_get_image_vmaddr_slide(i);
            break;
        }
    }

    uintptr_t linkeditBase = (uintptr_t)slide + linkedit->vmaddr - linkedit->fileoff;
    const struct nlist_64 *nl = (const struct nlist_64 *)(linkeditBase + symtab->symoff);
    const char *strtab = (const char *)(linkeditBase + symtab->stroff);

    if (!nl || !strtab) return symbols;

    for (uint32_t i = 0; i < symtab->nsyms; i++) {
        uint32_t strx = nl[i].n_un.n_strx;
        if (strx == 0) continue;

        const char *cname = strtab + strx;
        if (!cname) continue;

        NSString *name = [NSString stringWithUTF8String:cname];
        if (!CDLooksLikeSwiftSymbol(name)) continue;

        NSString *demangled = CDDemangleSwift(name);
        if (demangled.length) [symbols addObject:demangled];
    }

    return symbols;
}

static NSString *CDModuleFromDemangled(NSString *line) {
    NSRange dot = [line rangeOfString:@"."];
    if (dot.location == NSNotFound || dot.location == 0) return @"UnknownModule";

    NSString *m = [line substringToIndex:dot.location];
    if ([m containsString:@" "]) return @"UnknownModule";
    return m.length ? m : @"UnknownModule";
}

static NSString *CDTypeNameFromDemangled(NSString *line) {
    NSString *s = line;

    NSArray *keywords = @[@" class ", @" struct ", @" enum ", @" protocol "];
    for (NSString *kw in keywords) {
        NSRange r = [s rangeOfString:kw];
        if (r.location != NSNotFound) {
            NSString *tail = [s substringFromIndex:r.location + kw.length];
            NSArray *parts = [tail componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" :<({"]];
            NSString *name = parts.firstObject ?: @"Unknown";
            return name.length ? name : @"Unknown";
        }
    }

    NSArray *dotParts = [s componentsSeparatedByString:@"."];
    if (dotParts.count >= 2) {
        NSString *type = dotParts[1];
        NSRange paren = [type rangeOfString:@"("];
        if (paren.location != NSNotFound) type = [type substringToIndex:paren.location];
        if (type.length) return type;
    }

    return @"Global";
}

static NSString *CDKindFromDemangled(NSString *line) {
    if ([line containsString:@" protocol "]) return @"protocol";
    if ([line containsString:@" enum "]) return @"enum";
    if ([line containsString:@" struct "]) return @"struct";
    if ([line containsString:@" class "]) return @"class";
    return @"symbol";
}

static NSString *CDSwiftDeclarationFromLine(NSString *line) {
    if (line.length == 0) return nil;

    NSString *kind = CDKindFromDemangled(line);

    if ([kind isEqualToString:@"class"]) {
        NSString *name = CDTypeNameFromDemangled(line);
        return [NSString stringWithFormat:@"public class %@ {\n    // %@\n}\n", name, line];
    }

    if ([kind isEqualToString:@"struct"]) {
        NSString *name = CDTypeNameFromDemangled(line);
        return [NSString stringWithFormat:@"public struct %@ {\n    // %@\n}\n", name, line];
    }

    if ([kind isEqualToString:@"enum"]) {
        NSString *name = CDTypeNameFromDemangled(line);
        return [NSString stringWithFormat:@"public enum %@ {\n    // %@\n}\n", name, line];
    }

    if ([kind isEqualToString:@"protocol"]) {
        NSString *name = CDTypeNameFromDemangled(line);
        return [NSString stringWithFormat:@"public protocol %@ {\n    // %@\n}\n", name, line];
    }

    return [NSString stringWithFormat:@"// %@\n", line];
}

static void CDWriteSwiftIndex(NSString *rootDir, NSArray<NSString *> *allLines, NSMutableArray<NSString *> *written) {
    NSString *path = [rootDir stringByAppendingPathComponent:@"Swift/README_Swift.txt"];
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"Swift dump generated by ClassDumpExportPro\n\n"];
    [s appendString:@"说明：\n"];
    [s appendString:@"1. Swift 没有 Objective-C class-dump 那种完整头文件。\n"];
    [s appendString:@"2. 本插件扫描 Mach-O 符号表，并调用 swift_demangle 生成 Swift 伪接口。\n"];
    [s appendString:@"3. Release/strip/混淆后的 App 恢复率会明显下降。\n"];
    [s appendString:@"4. 方法体、private 符号、完整泛型约束、闭包签名无法完整还原。\n\n"];
    [s appendFormat:@"Swift demangled symbols: %lu\n\n", (unsigned long)allLines.count];

    NSUInteger max = MIN((NSUInteger)2000, allLines.count);
    for (NSUInteger i = 0; i < max; i++) {
        [s appendFormat:@"%@\n", allLines[i]];
    }

    [s writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [written addObject:path];
}

@implementation CDSwiftDumper

+ (NSArray<NSString *> *)dumpSwiftInterfacesAtRootDir:(NSString *)rootDir
                                             progress:(CDSwiftDumpProgressBlock)progress {

    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *swiftRoot = [rootDir stringByAppendingPathComponent:@"Swift"];
    NSString *classesDir = [swiftRoot stringByAppendingPathComponent:@"Classes"];
    NSString *structsDir = [swiftRoot stringByAppendingPathComponent:@"Structs"];
    NSString *enumsDir = [swiftRoot stringByAppendingPathComponent:@"Enums"];
    NSString *protocolsDir = [swiftRoot stringByAppendingPathComponent:@"Protocols"];
    NSString *symbolsDir = [swiftRoot stringByAppendingPathComponent:@"Symbols"];

    [fm createDirectoryAtPath:classesDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:structsDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:enumsDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:protocolsDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:symbolsDir withIntermediateDirectories:YES attributes:nil error:nil];

    NSMutableArray<NSString *> *written = [NSMutableArray array];
    NSMutableArray<NSString *> *allLines = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *grouped = [NSMutableDictionary dictionary];

    uint32_t count = _dyld_image_count();

    for (uint32_t i = 0; i < count; i++) {
        @autoreleasepool {
            const char *cpath = _dyld_get_image_name(i);
            const struct mach_header *mh = _dyld_get_image_header(i);
            if (!cpath || !mh) continue;

            NSString *imagePath = [NSString stringWithUTF8String:cpath];
            if (CDShouldSkipImage(imagePath)) continue;

            if (progress) {
                progress((CGFloat)i / (CGFloat)MAX(count, 1),
                         [NSString stringWithFormat:@"Swift扫描 %@", imagePath.lastPathComponent ?: @"Image"]);
            }

            NSArray<NSString *> *lines = CDSwiftSymbolsForImage(mh);
            if (lines.count == 0) continue;

            for (NSString *line in lines) {
                if (line.length == 0) continue;
                [allLines addObject:line];

                NSString *module = CDModuleFromDemangled(line);
                NSString *type = CDTypeNameFromDemangled(line);
                NSString *kind = CDKindFromDemangled(line);
                NSString *key = [NSString stringWithFormat:@"%@|%@|%@", kind, module, type];

                if (!grouped[key]) grouped[key] = [NSMutableArray array];
                [grouped[key] addObject:line];
            }
        }
    }

    NSArray<NSString *> *keys = [[grouped allKeys] sortedArrayUsingSelector:@selector(compare:)];

    NSUInteger idx = 0;
    for (NSString *key in keys) {
        @autoreleasepool {
            NSArray *parts = [key componentsSeparatedByString:@"|"];
            if (parts.count < 3) continue;

            NSString *kind = parts[0];
            NSString *module = CDSafeName(parts[1]);
            NSString *type = CDSafeName(parts[2]);
            NSArray<NSString *> *lines = grouped[key];

            NSString *dir = symbolsDir;
            if ([kind isEqualToString:@"class"]) dir = classesDir;
            else if ([kind isEqualToString:@"struct"]) dir = structsDir;
            else if ([kind isEqualToString:@"enum"]) dir = enumsDir;
            else if ([kind isEqualToString:@"protocol"]) dir = protocolsDir;

            NSString *file = [NSString stringWithFormat:@"%@_%@.swift", module, type];
            NSString *path = [dir stringByAppendingPathComponent:file];

            NSMutableString *content = [NSMutableString string];
            [content appendString:@"//\n"];
            [content appendString:@"// Swift pseudo interface dumped by ClassDumpExportPro\n"];
            [content appendString:@"// This is not original source code.\n"];
            [content appendString:@"//\n\n"];
            [content appendFormat:@"// Module: %@\n", module];
            [content appendFormat:@"// Type: %@\n", type];
            [content appendFormat:@"// Kind: %@\n\n", kind];

            if (![kind isEqualToString:@"symbol"]) {
                NSString *decl = CDSwiftDeclarationFromLine(lines.firstObject);
                if (decl.length) {
                    [content appendString:decl];
                    [content appendString:@"\n"];
                }
            }

            [content appendString:@"// MARK: - Demangled Symbols\n\n"];

            NSOrderedSet *unique = [NSOrderedSet orderedSetWithArray:lines];
            for (NSString *line in unique) {
                [content appendFormat:@"// %@\n", line];
            }

            [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
            [written addObject:path];

            idx++;
            if (progress) {
                progress((CGFloat)idx / (CGFloat)MAX(keys.count, 1),
                         [NSString stringWithFormat:@"Swift写入 %lu/%lu", (unsigned long)idx, (unsigned long)keys.count]);
            }
        }
    }

    CDWriteSwiftIndex(rootDir, allLines, written);

    return written;
}

@end
