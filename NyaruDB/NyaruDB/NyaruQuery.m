//
//  NyaruQuery.m
//  NyaruDB
//
//  Created by Kelp on 2012/10/08.
//  Copyright (c) 2012 Accuvally Inc. All rights reserved.
//

#import "NyaruQuery.h"

@implementation NyaruQuery

@synthesize schemaName = _schemaName;
@synthesize value = _value;
@synthesize operation = _operation;
@synthesize appendWith = _appendWith;

+ (id)queryWithSchemaName:(NSString *)schema operation:(NyaruQueryOperation)operation
{
    return [[NyaruQuery alloc] initWithSchemaName:schema operation:operation];
}
+ (id)queryWithSchemaName:(NSString *)schema operation:(NyaruQueryOperation)operation value:(id)value
{
    return [[NyaruQuery alloc] initWithSchemaName:schema operation:operation value:value];
}
+ (id)queryWithSchemaName:(NSString *)schema operation:(NyaruQueryOperation)operation value:(id)value appendWith:(NyaruAppendPrevious)appendWith
{
    return [[NyaruQuery alloc] initWithSchemaName:schema operation:operation value:value appendWith:appendWith];
}

- (id)init
{
    self = [super init];
    if (self) {
        _appendWith = NYAnd;
    }
    return self;
}

- (id)initWithSchemaName:(NSString *)schema operation:(NyaruQueryOperation)operation
{
    self = [self initWithSchemaName:schema operation:operation value:nil];
    return self;
}

- (id)initWithSchemaName:(NSString *)schema operation:(NyaruQueryOperation)operation value:(id)value
{
    self = [self init];
    if (self) {
        _schemaName = schema;
        _value = value == nil ? [NSNull null] : value;
        _operation = operation;
    }
    return self;
}

- (id)initWithSchemaName:(NSString *)schema operation:(NyaruQueryOperation)operation value:(id)value appendWith:(NyaruAppendPrevious)appendWith
{
    self = [self initWithSchemaName:schema operation:operation value:value];
    if (self) {
        _appendWith = appendWith;
    }
    return self;
}

@end
