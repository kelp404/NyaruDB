//
//  NyaruDB.m
//  NyaruDB
//
//  Created by Kelp on 2013/02/18.
//
/*
 Document formate
 [K]<0xFFFFFFFF>{key}[SNTLDA]<0xFFFFFFFF>{value}
 
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
#import "NyaruConfig.h"
#import "NyaruCollection.h"


// these are for passing Cocoapods Travis CI build [function-declaration]
@interface NyaruDB()
NYARU_BURST_LINK NSMutableDictionary *loadCollections(NSString *databasePath);
@end



@implementation NyaruDB

static NyaruDB *_instance;


#pragma mark - Static methods
+ (id)instance
{
    @synchronized(_instance) {
        if (!_instance) {
            _instance = [self new];
        }
        return _instance;
    }
}

+ (void)reset
{
    @try {
        if (_instance) { [_instance removeAllCollections]; }
    }
    @catch (__unused NSException *exception) { }
    _instance = nil;
    
    NSString *path = ((NSArray *)NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)).lastObject;
    NSString *databasePath = [path stringByAppendingPathComponent:NYARU_PRODUCT];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:databasePath]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:databasePath error:&error];
        if (error) {
            @throw([NSException exceptionWithName:NYARU_PRODUCT reason:error.description userInfo:error.userInfo]);
        }
    }
}


#pragma mark - Init
- (id)init
{
    self = [super init];
    if (self) {
        NSString *path = ((NSArray *)NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)).lastObject;
        _databasePath = [path stringByAppendingPathComponent:NYARU_PRODUCT];
        
        // if database path does not exists then create it
        if (![[NSFileManager defaultManager] fileExistsAtPath:_databasePath]) {
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:_databasePath withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                @throw([NSException exceptionWithName:NYARU_PRODUCT reason:error.description userInfo:error.userInfo]);
            }
        }
        
        // load collections
        _collections = loadCollections(_databasePath);
    }
    return self;
}
- (id)initWithPath:(NSString *)path
{
    self = [super init];
    if (self) {
        _databasePath = path;
        
        // if database path does not exists then create it
        if (![[NSFileManager defaultManager] fileExistsAtPath:_databasePath]) {
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:_databasePath withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                @throw([NSException exceptionWithName:NYARU_PRODUCT reason:error.description userInfo:error.userInfo]);
            }
        }
        
        // load collections
        _collections = loadCollections(_databasePath);
    }
    return self;
}


#pragma mark - Collection
- (NyaruCollection *)collection:(NSString *)name
{
    if (name.length == 0U) { return nil; }
    
    NyaruCollection *result = _collections[name];
    if (result) {
        return result;
    }
    else {
        // create collection
        NyaruCollection *collection = [[NyaruCollection alloc] initWithNewCollectionName:name databasePath:_databasePath];
        if (collection) {
            [_collections setObject:collection forKey:name];
        }
        return collection;
    }
}
- (NSArray *)collections
{
    return _collections.allValues;
}
- (void)removeCollection:(NSString *)name
{
    NyaruCollection *collection = _collections[name];
    if (collection) {
        [_collections removeObjectForKey:name];
        [collection close];
        [collection removeCollectionFiles];
        collection = nil;
    }
}
- (void)removeAllCollections
{
    NSArray *collections = _collections.allValues;
    [_collections removeAllObjects];
    for (NyaruCollection *collection in collections) {
        [collection close];
        [collection removeCollectionFiles];
    }
}


#pragma mark - Close
- (void)close
{
    for (NyaruCollection *co in _collections.allValues) {
        [co close];
    }
}


#pragma mark - Private
/**
 Load all collections from files for init.
 
 @param databasePath database path. it is a folder.
 @return return NSMutableDictionary (key: collection name, value: collection)
 */
NYARU_BURST_LINK NSMutableDictionary *loadCollections(NSString *databasePath)
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:databasePath error:nil];
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"self ENDSWITH '.index'"];
    NSArray *indexes = [dirContents filteredArrayUsingPredicate:filter];  // get .index in the path
    
    for (NSString *index in indexes) {
        // index is like "name.index"
        // get the file name from full-path and remove extension
        NSString *name = [index stringByDeletingPathExtension];
        
        // load collection
        NyaruCollection *collection = [[NyaruCollection alloc] initWithLoadCollectionName:name databasePath:databasePath];
        if (collection) {
            [result setObject:collection forKey:collection.name];
        }
    }
    
    return result;
}


@end
