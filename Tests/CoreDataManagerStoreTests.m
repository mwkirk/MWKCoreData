//
//  CoreDataManagerStoreTests.m
//  MWKCoreData
//
//  Created by Mark Kirk on 6/17/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <MWKCoreData/MWKCoreData.h>
#import "TestUtil.h"


@interface CoreDataManagerStoreTests : XCTestCase

@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) NSManagedObjectModel *modelVersion1;
@property (nonatomic, strong) NSManagedObjectModel *modelVersion2;

@end

@implementation CoreDataManagerStoreTests

- (void)setUp
{
    [super setUp];
    
    self.bundle = [NSBundle bundleForClass:[self class]];
}


- (NSManagedObjectModel*)modelVersion1
{
    if (!_modelVersion1) {
        _modelVersion1 = [TestUtil modelWithName:@"MWKCoreDataTests" version:@"" inBundle:self.bundle];
    }
    
    return _modelVersion1;
}


- (NSManagedObjectModel*)modelVersion2
{
    if (!_modelVersion2) {
        _modelVersion2 = [TestUtil modelWithName:@"MWKCoreDataTests" version:@"2" inBundle:self.bundle];
    }
    
    return _modelVersion2;
}


#pragma - Tests

- (void)testRequiresMigrationForIncompatibleModels
{
    // Copy a version 1 store for testing
    NSURL *storeVersion1Url = [TestUtil copyFixtureStoreWithNameToRandomURL:@"MWKCoreDataTests.sqlite"];
    
    // Create CoreDataManager using model version 2 and the version 1 store
    CoreDataManager *mgr = [[CoreDataManager alloc] initWithManagedObjectModel:self.modelVersion2
                                                        persistentStoreOptions:nil
                                                           persistentStoreType:nil
                                                             persisentStoreURL:storeVersion1Url
                                                                        bundle:self.bundle];
    XCTAssertTrue(mgr.requiresMigration);
    
    // Clean up
    [TestUtil removeSQLitePersistentStoreAtURL:storeVersion1Url];
}


- (void)testRequiresMigrationForCompatibleModels
{
    // Copy a version 1 store for testing
    NSURL *storeVersion1Url = [TestUtil copyFixtureStoreWithNameToRandomURL:@"MWKCoreDataTests.sqlite"];
    
    // Create CoreDataManager using model version 1
    CoreDataManager *mgr = [[CoreDataManager alloc] initWithManagedObjectModel:self.modelVersion1
                                                        persistentStoreOptions:nil
                                                           persistentStoreType:nil
                                                             persisentStoreURL:storeVersion1Url
                                                                        bundle:self.bundle];
    XCTAssertFalse(mgr.requiresMigration);

    // Clean up
    [TestUtil removeSQLitePersistentStoreAtURL:storeVersion1Url];
}


- (void)testLightWeightMigrationPossibleForIncompatibleModels
{
    // Copy a version 1 store for testing
    NSURL *storeVersion1Url = [TestUtil copyFixtureStoreWithNameToRandomURL:@"MWKCoreDataTests.sqlite"];
    
    // Create CoreDataManager using model version 2 and the version 1 store
    CoreDataManager *mgr = [[CoreDataManager alloc] initWithManagedObjectModel:self.modelVersion2
                                                        persistentStoreOptions:nil
                                                           persistentStoreType:nil
                                                             persisentStoreURL:storeVersion1Url
                                                                        bundle:self.bundle];
    XCTAssertTrue(mgr.requiresMigration);
    XCTAssertTrue(mgr.lightweightMigrationPossible);
    
    // Clean up
    [TestUtil removeSQLitePersistentStoreAtURL:storeVersion1Url];
}


- (void)testLightWeightMigrationPossibleForCompatibleModels
{
    // Copy a version 1 store for testing
    NSURL *storeVersion1Url = [TestUtil copyFixtureStoreWithNameToRandomURL:@"MWKCoreDataTests.sqlite"];
    
    // Create CoreDataManager using model version 1
    CoreDataManager *mgr = [[CoreDataManager alloc] initWithManagedObjectModel:self.modelVersion1
                                                        persistentStoreOptions:nil
                                                           persistentStoreType:nil
                                                             persisentStoreURL:storeVersion1Url
                                                                        bundle:self.bundle];
    XCTAssertTrue(mgr.lightweightMigrationPossible);
    
    // Clean up
    [TestUtil removeSQLitePersistentStoreAtURL:storeVersion1Url];
}


- (void)testStackInitializationForIncompatibleModels
{
    // Copy a version 1 store for testing
    NSURL *storeVersion1Url = [TestUtil copyFixtureStoreWithNameToRandomURL:@"MWKCoreDataTests.sqlite"];
    
    // Create CoreDataManager using model version 2
    CoreDataManager *mgr = [[CoreDataManager alloc] initWithManagedObjectModel:self.modelVersion2
                                                        persistentStoreOptions:nil
                                                           persistentStoreType:nil
                                                             persisentStoreURL:storeVersion1Url
                                                                        bundle:self.bundle];

    // We shouldn't be able to initialize the stack with incompatible models (migration required)
    NSError *error = nil;
    XCTAssertFalse([mgr initializeStack:&error]);
    XCTAssertNotNil(error);
    
    // Clean up
    [TestUtil removeSQLitePersistentStoreAtURL:storeVersion1Url];
}

@end
