//
//  NyaruIndex.m
//  NyaruDB
//
//  Created by Kelp on 2013/02/19.
//
//

#import "NyaruIndex.h"

@implementation NyaruIndex


- (id)init
{
    self = [super init];
    if (self) {
        _keySet = [NSMutableSet new];
    }
    return self;
}

- (id)initWithIndexValue:(id)value key:(NSString *)key
{
    self = [super init];
    if (self) {
        _keySet = [[NSMutableSet alloc] initWithObjects:key, nil];
        _value = value;
    }
    return self;
}

@end
