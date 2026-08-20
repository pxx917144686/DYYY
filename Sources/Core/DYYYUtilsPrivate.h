//
//  DYYYUtilsPrivate.h
//  DYYY
//
//  DYYYUtils 拆分后跨文件共享的内部 C 函数声明。仅限 Sources/Core 内部文件引用，
//  不要暴露到业务层：业务层统一通过 DYYYUtils.h。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 配置内存缓存（主文件 DYYYUtils.m 持有，DYYYUtilsConfig.m 的失效逻辑需要访问）。
NSMutableDictionary *DYYYConfigCache(void);

// 关键词列表预编译缓存（主文件 DYYYUtils.m 持有，同上）。
NSMutableDictionary *DYYYKeywordListCache(void);

NS_ASSUME_NONNULL_END
