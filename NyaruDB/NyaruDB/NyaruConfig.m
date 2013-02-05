//
//  NyaruConfig.h
//  NyaruDB
//
//  Created by Kelp on 12/8/12.
//

#import "NyaruConfig.h"

@implementation NyaruConfig

static NSString *_key = @"key";
static NSString *_indexOffset = @"io";
static NSString *_blockLength = @"bl";

+ (NSString *)key
{
    return _key;
}

/**
 for Cleared Index Block
 */
+ (NSString *)indexOffset
{
    return _indexOffset;
}
/**
 for Cleared Index Block
 */
+ (NSString *)blockLength
{
    return _blockLength;
}

@end
