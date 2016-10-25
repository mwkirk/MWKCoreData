//
//  MigrationTests.m
//  MWKCoreData
//
//  Created by Mark Kirk on 6/18/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <MWKCoreData/MWKCoreData.h>
#import "TestUtil.h"

@interface MigrationTests : XCTestCase

@end

@implementation MigrationTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInferredMigrationFromModelVersion1ToModelVersion2
{
    // Copy a version 1 store for testing
    NSURL *storeVersion1Url = [TestUtil copyFixtureStoreWithNameToRandomURL:@"MWKCoreDataTests.sqlite"];
    
    // Create CoreDataManager using model version 2 and the version 1 store
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSManagedObjectModel *modelVersion2 = [TestUtil modelWithName:@"MWKCoreDataTests" version:@"2" inBundle:testBundle];

    CoreDataManager *mgr = [[CoreDataManager alloc] initWithManagedObjectModel:modelVersion2
                                                        persistentStoreOptions:nil
                                                           persistentStoreType:nil
                                                             persisentStoreURL:storeVersion1Url
                                                                        bundle:testBundle];
    
    XCTAssertTrue(mgr.requiresMigration && mgr.lightweightMigrationPossible);
    
    
    [mgr migrateWithProgress:^(NSUInteger aPass, float aProgress) {
        NSLog(@"pass %tu with progess %.2f", aPass, aProgress);
    }
                  completion:^(BOOL aSuccess, NSError *aError, NSURL *aOriginalSrcStoreBackupURL, UIBackgroundTaskIdentifier aBgTask) {
                      XCTAssertTrue(aSuccess);
                      XCTAssertNil(aError);
                      
                      NSFileManager *fm = [NSFileManager defaultManager];
                      XCTAssertTrue([fm fileExistsAtPath:aOriginalSrcStoreBackupURL.path]);
                      
                      [[UIApplication sharedApplication] endBackgroundTask:aBgTask];
                  }];
}



- (void)testCustomMigrationFromModelVersion2ToModelVersion3
{
    // Copy a version 2 store for testing
    NSURL *storeVersion2Url = [TestUtil copyFixtureStoreWithNameToRandomURL:@"MWKCoreDataTests2.sqlite"];
    
    // Create CoreDataManager using model version 3 and the version 2 store
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSManagedObjectModel *modelVersion3 = [TestUtil modelWithName:@"MWKCoreDataTests" version:@"3" inBundle:testBundle];
    
    CoreDataManager *mgr = [[CoreDataManager alloc] initWithManagedObjectModel:modelVersion3
                                                        persistentStoreOptions:nil
                                                           persistentStoreType:nil
                                                             persisentStoreURL:storeVersion2Url
                                                                        bundle:testBundle];
    
    XCTAssertTrue(mgr.requiresMigration);
    
    [mgr migrateWithProgress:^(NSUInteger aPass, float aProgress) {
        NSLog(@"pass %tu with progess %.2f", aPass, aProgress);
    }
                  completion:^(BOOL aSuccess, NSError *aError, NSURL *aOriginalSrcStoreBackupURL, UIBackgroundTaskIdentifier aBgTask) {
                      XCTAssertTrue(aSuccess);
                      XCTAssertNil(aError);
                      
                      NSFileManager *fm = [NSFileManager defaultManager];
                      XCTAssertTrue([fm fileExistsAtPath:aOriginalSrcStoreBackupURL.path]);
                      NSLog(@"orginal store backup: %@", aOriginalSrcStoreBackupURL.path);
                      NSLog(@"migrated store: %@", storeVersion2Url.path);
                      
                      [[UIApplication sharedApplication] endBackgroundTask:aBgTask];
                  }];
    
    // @TODO: Might want to add some code to validate assumptions about the migrated store
}


// @TODO: This test does perform two migration passes (inferred, then custom), but it isn't as interesting
//        as it could be since the v1 fixture store doesn't have any "dept" entities
- (void)testMultiPassMigrationFromModelVersion1ToModelVersion3
{
    // Copy a version 1 store for testing
    NSURL *storeVersion1Url = [TestUtil copyFixtureStoreWithNameToRandomURL:@"MWKCoreDataTests.sqlite"];
    
    // Create CoreDataManager using model version 3 and the version 1 store
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSManagedObjectModel *modelVersion3 = [TestUtil modelWithName:@"MWKCoreDataTests" version:@"3" inBundle:testBundle];
    
    CoreDataManager *mgr = [[CoreDataManager alloc] initWithManagedObjectModel:modelVersion3
                                                        persistentStoreOptions:nil
                                                           persistentStoreType:nil
                                                             persisentStoreURL:storeVersion1Url
                                                                        bundle:testBundle];
    
    XCTAssertTrue(mgr.requiresMigration);
    
    [mgr migrateWithProgress:^(NSUInteger aPass, float aProgress) {
        NSLog(@"pass %tu with progess %.2f", aPass, aProgress);
    }
                  completion:^(BOOL aSuccess, NSError *aError, NSURL *aOriginalSrcStoreBackupURL, UIBackgroundTaskIdentifier aBgTask) {
                      XCTAssertTrue(aSuccess);
                      XCTAssertNil(aError);
                      
                      NSFileManager *fm = [NSFileManager defaultManager];
                      XCTAssertTrue([fm fileExistsAtPath:aOriginalSrcStoreBackupURL.path]);
                      NSLog(@"orginal store backup: %@", aOriginalSrcStoreBackupURL.path);
                      NSLog(@"migrated store: %@", storeVersion1Url.path);
                      
                      [[UIApplication sharedApplication] endBackgroundTask:aBgTask];
                  }];
    
    // @TODO: Might want to add some code to validate assumptions about the migrated store
}


@end
