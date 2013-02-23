//
//  NyaruIndexBlock.m
//  NyaruDB
//
//  Created by Kelp on 2013/02/19.
//
//

#import "NyaruIndexBlock.h"

@implementation NyaruIndexBlock

@synthesize indexOffset = _indexOffset;
@synthesize blockLength = _blockLength;


/**
 Get a NyaruIndexBlock instance.
 @param offset index offset
 @param length block length
 @return NyaruIndexBlock instance
 */
- (id)initWithOffset:(NSUInteger)offset andLength:(NSUInteger)length
{
    self = [super init];
    if (self) {
        _indexOffset = offset;
        _blockLength = length;
    }
    return self;
}

+ (NyaruIndexBlock *)indexBlockWithOffset:(NSUInteger)offset andLength:(NSUInteger)length
{
    NyaruIndexBlock *instance = [[NyaruIndexBlock alloc] initWithOffset:offset andLength:length];
    return instance;
}


@end
