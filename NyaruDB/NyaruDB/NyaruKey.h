//
//  NyaruIndex.h
//  NyaruDB
//
//  Created by Kelp on 12/9/3.
//  Copyright (c) 2012 Accuvally Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NyaruKey : NSObject

@property (nonatomic) unsigned int indexOffset;
@property (nonatomic) unsigned int documentOffset;
@property (nonatomic) unsigned int documentLength;
@property (nonatomic) unsigned int blockLength;

- (id)initWithIndexOffset:(unsigned int)index documentOffset:(unsigned int)offset documentLength:(unsigned int)length blockLength:(unsigned int)blockLength;

@end
