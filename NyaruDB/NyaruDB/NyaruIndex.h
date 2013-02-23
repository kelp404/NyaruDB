//
//  NyaruIndex.h
//  NyaruDB
//
//  Created by Kelp on 2013/02/19.
//
//

#import <Foundation/Foundation.h>

@interface NyaruIndex : NSObject

@property (strong, nonatomic) NSMutableSet *keySet;
@property (strong, nonatomic) id value;

- (id)initWithIndexValue:(id)value key:(NSString *)key;

@end
