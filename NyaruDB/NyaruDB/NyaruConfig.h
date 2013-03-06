//
//  NyaruConfig.h
//  NyaruDB
//
//  Created by Kelp on 2013/02/18.
//
//

#import <Foundation/Foundation.h>
#import "JSONKit-Nyaru.h"

#pragma mark - NyaruDB Config

/**
 The limit of caching documents for fetch.
 */
#define NYARU_CACHE_LIMIT 100


#define NYARU_PRODUCT @"NyaruDB"
#define NYARU_HEADER @"(」・ω・)」うー！(／・ω・)／にゃー！1\n"
#define NYARU_HEADER_LENGTH 0x37

#define NYARU_SCHEMA @"schema"
#define NYARU_INDEX @"index"
#define NYARU_DOCUMENT @"document"

#define NYARU_KEY @"key"

#pragma mark - NyaruDB Base Settings
#if defined (__GNUC__) && (__GNUC__ >= 4)
#define NYARU_ATTRIBUTES(attr, ...) __attribute__((attr, ##__VA_ARGS__))
#else  // defined (__GNUC__) && (__GNUC__ >= 4)
#define NYARU_ATTRIBUTES(attr, ...)
#endif
#define NYARU_BURST_LINK static __inline__ NYARU_ATTRIBUTES(always_inline)

