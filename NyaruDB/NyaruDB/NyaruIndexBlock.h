//
//  NyaruIndexBlock.h
//  NyaruDB
//
//  Created by Kelp on 2013/02/19.
//
//

#import <Foundation/Foundation.h>

@interface NyaruIndexBlock : NSObject

/**
 NyaruDB index offset.
 */
@property (nonatomic, readonly) NSUInteger indexOffset;
/**
 NyaruDB index block length.
 */
@property (nonatomic, readonly) NSUInteger blockLength;

/**
 Get a NyaruIndexBlock instance.
 @param offset index offset
 @param length block length
 @return NyaruIndexBlock instance
 */
+ (NyaruIndexBlock *)indexBlockWithOffset:(NSUInteger)offset andLength:(NSUInteger)length;


@end
