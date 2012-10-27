//
//  NyaruConfig.h
//  NyaruDB
//
//  Created by Kelp on 12/8/12.
//  Copyright (c) 2012 Accuvally Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JSONKit-Nyaru.h"
#import "NSData+GZIP.h"

#pragma mark - NyaruDB Config
#define NyaruDBNProduct @"NyaruDB"
#define NyaruFileHeader @"(」・ω・)」うー！(／・ω・)／にゃー！ \n"
#define NyaruFileHeaderLength 0x37

#define NyaruSchemaExtension @"schema"
#define NyaruIndexExtension @"index"
#define NyaruDocumentExtension @"document"


#pragma mark - NyaruDB Base Settings
#if defined (__GNUC__) && (__GNUC__ >= 4)
#define NYARU_ATTRIBUTES(attr, ...) __attribute__((attr, ##__VA_ARGS__))
#else  // defined (__GNUC__) && (__GNUC__ >= 4)
#define NYARU_ATTRIBUTES(attr, ...)
#endif

#define BURST_LINK static __inline__ NYARU_ATTRIBUTES(always_inline)


@interface NyaruConfig : NSObject

enum {
    NyaruSchemaTypeNumber = 0,
    NyaruSchemaTypeString = 1,
    NyaruSchemaTypeDate = 2,
    NyaruSchemaTypeNil = 3,
    NyaruSchemaTypeOther = 4,
};
typedef unsigned int NyaruSchemaType;

+ (NSString *)key;
+ (NSString *)indexOffset;
+ (NSString *)blockLength;

@end
