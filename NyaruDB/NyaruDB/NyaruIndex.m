//
//  NyaruIndex.m
//  NyaruDB
//
//  Created by Kelp on 12/9/3.
//  Copyright (c) 2012 Accuvally Inc. All rights reserved.
//

#import "NyaruIndex.h"

@implementation NyaruIndex

@synthesize key = _key;
@synthesize value = _value;

- (id)initWithIndexValue:(id)value key:(NSString *)key
{
    self = [super init];
    if (self) {
        _key = key;
        _value = value;
    }
    return self;
}

@end
