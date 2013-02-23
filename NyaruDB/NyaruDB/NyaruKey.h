//
//  NyaruKey.h
//  NyaruDB
//
//  Created by Kelp on 2013/02/19.
//
//

#import <Foundation/Foundation.h>

@interface NyaruKey : NSObject

@property (nonatomic) unsigned int indexOffset;
@property (nonatomic) unsigned int documentOffset;
@property (nonatomic) unsigned int documentLength;
@property (nonatomic) unsigned int blockLength;

- (id)initWithIndexOffset:(unsigned int)index documentOffset:(unsigned int)offset documentLength:(unsigned int)length blockLength:(unsigned int)blockLength;

@end
