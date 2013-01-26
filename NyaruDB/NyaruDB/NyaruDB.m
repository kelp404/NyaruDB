//
//  NyaruDB.m
//  NyaruDB
//
//  Created by Kelp on 12/7/14.
//
/*
 Normal Field Datatype:
    NSNull
    NSNumber (true: 1, false: 0)
    NSDate
    NSString
    NSArray
    NSDictionary
 
 Schema Datatype:
    NSNull
    NSNumber (true: 1, false: 0)
    NSDate
    NSString
*/
/*
 Database:
    NyaruCollection: Members
    NyaruCollection: Tickets
    ...................
 
 NyaruCollection:
    Schema (_schema) {name.schema}
        NyaruSchema: 0, "key"
        NyaruSchema: 1, "email"
        ...................
 
    Unique Index (_index)           {name.index}    schema is 'key'
        Dictionary type index
        Key: value of key
        Value: NyaruKey (value in memory when field is Index)
    Index (_index)                      {name.index}
        Array type index
 
    Document                            {name.document}
        JSON data
        JSON data
        ..................
 
 ←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙
 
 Attention:
    limit length of name of field is 255
    limit of datas is 4,294,967,295
    limit of document size is 4G
    key is unique and it is NSString
    key does not provide searching by query
    key is case sensitive
    index is case insensitive
    a field of data should be same data type which is schema
    sort query allow only one
 
 ←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙←↖↑↗→↘↓↙
 
 Document formate
 Data is Document content
 
 Schema formate
 Previous    　 FF | FF | FF | FF |
 Next         　 FF | FF | FF | FF |
 Data Length   FF |
 Data is name of Key
 
 Index formate
 Document Offset    FF | FF | FF | FF |
 Document Length   FF | FF | FF | FF |
 Block Length         FF | FF | FF | FF |
 
*/


#import "NyaruDB.h"

@interface NyaruDB()
- (NSMutableDictionary *)loadCollections;
@end


@implementation NyaruDB

@synthesize databasePath = _databasePath;

static NyaruDB *_instance;

+ (id)sharedInstance
{
    @synchronized(_instance) {
        if (_instance == nil) {
            _instance = [self new];
        }
        return _instance;
    }
}

// remove all database. if you init database error, maybe need to call this message.
+ (void)reset
{
    _instance = nil;
    
    NSString *path = ((NSArray *)NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)).lastObject;
    NSString *databasePath = [path stringByAppendingPathComponent:NyaruDBNProduct];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:databasePath]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:databasePath error:&error];
        if (error) {
            @throw([NSException exceptionWithName:NyaruDBNProduct reason:error.description userInfo:error.userInfo]);
        }
    }
}


#pragma mark - Init
- (id)init
{
    self = [super init];
    if (self) {
        NSString *path = ((NSArray *)NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)).lastObject;
        _databasePath = [path stringByAppendingPathComponent:NyaruDBNProduct];
        
        // if database path does not exists then create it
        if(![[NSFileManager defaultManager] fileExistsAtPath:_databasePath]) {
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:_databasePath withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                @throw([NSException exceptionWithName:NyaruDBNProduct reason:error.description userInfo:error.userInfo]);
            }
        }
        
        // load collections
        _collections = self.loadCollections;
    }
    return self;
}

- (NSMutableDictionary *)loadCollections
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_databasePath error:nil];
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"self ENDSWITH '.index'"];
    NSArray *indexes = [dirContents filteredArrayUsingPredicate:filter];  // get .index in the path
    
    for (NSString *index in indexes) {
        // index is like "name.index"
        // get the file name from full-path and remove extension
        NSString *name = [index stringByDeletingPathExtension];
        
        // load collection
        NyaruCollection *collection = [[NyaruCollection alloc] initWithLoadCollectionName:name databasePath:_databasePath];
        if (collection) {
            [result setObject:collection forKey:collection.name];
        }
    }
    
    return result;
}


#pragma mark - Read Collection
- (NSDictionary *)allCollections
{
    return _collections;
}

- (NyaruCollection *)collectionForName:(NSString *)name
{
    return (NyaruCollection *)[_collections objectForKey:name];
}


#pragma mark - Write Collection
// remove collection, than create a new one
// success: return a new collection,    failed: return nil
- (NyaruCollection *)createCollection:(NSString *)name
{
    // remove
    [self removeCollection:name];
    
    // create
    NSPredicate *filter = [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"self == '%@'", name]];
    NSArray *key = [_collections.allKeys filteredArrayUsingPredicate:filter];
    if (key.count > 0) {
        return nil;
    }
    
    if (name == nil || name.length == 0) {
        return nil;
    }
    
    NyaruCollection *collection = [[NyaruCollection alloc] initWithNewCollectionName:name databasePath:_databasePath];
    if (collection) {
        [_collections setObject:collection forKey:name];
    }
    return collection;
}

- (void)removeCollection:(NSString *)name
{
    NyaruCollection *collection = [_collections objectForKey:name];
    if (collection) {
        [collection remove];
        [_collections removeObjectForKey:name];
    }
    else {
        NSString *indexFilePath = [[_databasePath stringByAppendingPathComponent:name] stringByAppendingPathExtension:NyaruIndexExtension];
        NSString *schemaFilePath = [[_databasePath stringByAppendingPathComponent:name] stringByAppendingPathExtension:NyaruSchemaExtension];
        NSString *documentFilePath = [[_databasePath stringByAppendingPathComponent:name] stringByAppendingPathExtension:NyaruDocumentExtension];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:documentFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:documentFilePath error:nil];
        }
        if ([[NSFileManager defaultManager] fileExistsAtPath:indexFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:indexFilePath error:nil];
        }
        if ([[NSFileManager defaultManager] fileExistsAtPath:schemaFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:schemaFilePath error:nil];
        }
    }
}


@end
