//
//  NyaruIndexBlock.m
//  NyaruDB
//
//  Created by Kelp on 2013/02/19.
//
//

#import "NyaruIndexBlock.h"

@implementation NyaruIndexBlock


/**
 Get a NyaruIndexBlock instance.
 @param offset index offset
 @param length block length
 @return NyaruIndexBlock instance
 */
- (id)initWithOffset:(unsigned)offset andLength:(unsigned)length
{
    self = [super init];
    if (self) {
        _indexOffset = offset;
        _blockLength = length;
    }
    return self;
}


@end
