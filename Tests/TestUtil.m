//
//  TestUtils.m
//  MWKCoreData
//
//  Created by Mark Kirk on 6/17/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//

#import "TestUtil.h"

@implementation TestUtil

+ (void)removeSQLitePersistentStoreAtURL:(NSURL*)aStoreUrl
{
    NSURL *baseUrl = [aStoreUrl URLByDeletingLastPathComponent];
    NSString *dbName = [aStoreUrl lastPathComponent];
    
    NSURL *shmUrl = [baseUrl URLByAppendingPathComponent:[dbName stringByAppendingString:@"-shm"]];
    NSURL *walUrl = [baseUrl URLByAppendingPathComponent:[dbName stringByAppendingString:@"-wal"]];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtURL:aStoreUrl error:nil];
    [fm removeItemAtURL:shmUrl error:nil];
    [fm removeItemAtURL:walUrl error:nil];
}


+ (NSManagedObjectModel*)modelWithName:(NSString*)aModelName
                               version:(NSString*)aVersion
                              inBundle:(NSBundle*)aBundle
{
    if (!aBundle) aBundle = [NSBundle mainBundle];
    
    NSString *resource = [NSString stringWithFormat:@"%@.momd/%@%@", aModelName, aModelName, aVersion];
    NSURL *modelURL = [aBundle URLForResource:resource withExtension:@"mom"];
    NSAssert(modelURL,@"Unable to find MOM - %@",resource);
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSAssert(model,@"Unable to load MOM at URL- %@",modelURL);
    return model;
}


// SQLite fixture stores should have been saved in rollback mode (no -wal files)
+ (NSURL*)copyFixtureStoreWithNameToRandomURL:(NSString*)aName
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *src = [bundle pathForResource:[aName stringByDeletingPathExtension] ofType:[aName pathExtension]];
    NSAssert([[NSFileManager defaultManager] fileExistsAtPath:src], @"No source store at %@", src);
    
    NSString *uniqueName = [NSProcessInfo processInfo].globallyUniqueString;
    NSString *dest = [[NSTemporaryDirectory() stringByAppendingString:uniqueName] stringByAppendingPathExtension:[aName pathExtension]];
    
    [[NSFileManager defaultManager] copyItemAtPath:src toPath:dest error:nil];
    NSAssert([[NSFileManager defaultManager] fileExistsAtPath:dest], @"Copy failed to %@", dest);
    
    return [NSURL fileURLWithPath:dest];
}

@end
