//
//  NyaruSchemaTest.m
//  NyaruDB
//
//  Created by Kelp on 2013/03/23.
//
//

#import "NyaruSchemaTest.h"
#import "NyaruSchema.h"


@implementation NyaruSchemaTest

- (void)testCreateSchema
{
    NyaruSchema *schema1 = [[NyaruSchema alloc] initWithName:@"key" previousOffser:0U nextOffset:0U];
    schema1.offsetInFile = 9U;
    
    NyaruSchema *schema2 = [[NyaruSchema alloc] initWithName:@"name" previousOffser:9U nextOffset:0U];
    schema2.offsetInFile = 10U;
    schema1.nextOffsetInFile = 10U;
    
    STAssertEqualObjects(schema1.name, @"key", nil);
    STAssertTrue(schema1.unique, nil);
    STAssertEquals(schema1.previousOffsetInFile, 0U, nil);
    STAssertEquals(schema1.offsetInFile, 9U, nil);
    STAssertEquals(schema1.nextOffsetInFile, 10U, nil);
    STAssertEquals(schema1.schemaType, NyaruSchemaTypeString, nil);
    
    STAssertEqualObjects(schema2.name, @"name", nil);
    STAssertFalse(schema2.unique, nil);
    STAssertEquals(schema2.previousOffsetInFile, 9U, nil);
    STAssertEquals(schema2.offsetInFile, 10U, nil);
    STAssertEquals(schema2.nextOffsetInFile, 0U, nil);
    STAssertEquals(schema2.schemaType, NyaruSchemaTypeUnknow, nil);
}

- (void)testSerializer
{
    NyaruSchema *schema = [[NyaruSchema alloc] initWithName:@"key" previousOffser:10U nextOffset:30U];
    NSData *data = schema.dataFormate;
    schema = [[NyaruSchema alloc] initWithData:data andOffset:20U];
    
    STAssertEqualObjects(schema.name, @"key", nil);
    STAssertTrue(schema.unique, nil);
    STAssertEquals(schema.previousOffsetInFile, 10U, nil);
    STAssertEquals(schema.offsetInFile, 20U, nil);
    STAssertEquals(schema.nextOffsetInFile, 30U, nil);
    STAssertEquals(schema.schemaType, NyaruSchemaTypeString, nil);
}

@end
