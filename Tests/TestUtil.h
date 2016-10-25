//
//  TestUtil.h
//  MWKCoreData
//
//  Created by Mark Kirk on 6/17/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface TestUtil : NSObject

+ (void)removeSQLitePersistentStoreAtURL:(NSURL*)aStoreUrl;

+ (NSManagedObjectModel*)modelWithName:(NSString*)aModelName
                               version:(NSString*)aVersion
                              inBundle:(NSBundle*)aBundle;

+ (NSURL*)copyFixtureStoreWithNameToRandomURL:(NSString*)aName;

@end
