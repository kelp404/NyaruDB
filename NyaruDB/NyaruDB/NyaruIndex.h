//
//  NyaruIndex.h
//  NyaruDB
//
//  Created by Kelp on 12/9/3.
//

#import <Foundation/Foundation.h>

@interface NyaruIndex : NSObject

@property (strong, nonatomic) NSString *key;
@property (strong, nonatomic) id value;

- (id)initWithIndexValue:(id)value key:(NSString *)key;

@end
