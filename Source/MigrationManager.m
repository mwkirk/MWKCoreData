 //
//  MigrationManager.m
//  MWKCoreData
//
//  Created by Mark Kirk on 6/19/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//  MIT License. Please see the included LICENSE file of the
//  software https://github.com/mwkirk/MWKCoreData
//
//  Based largely upon the excellent objc.io Issue #4 article
//  "Custom Core Data Migrations" by Martin Hwasser and his
//  accompanying example code (used under the MIT License):
//  https://www.objc.io/issues/4-core-data/core-data-migration/
//  https://github.com/objcio/issue-4-core-data-migration
//  MHWMigrationManager.h
//  BookMigration
//
//  Created by Martin Hwasser on 8/30/13.
//  Copyright (c) 2013 Martin Hwasser. All rights reserved.
//


#import "MigrationManager.h"
#import "MWKCoreDataError.h"
#import <CoreData/CoreData.h>


static void* kMigrationProgressCtx = &kMigrationProgressCtx;

@interface MigrationManager ()

@property (nonatomic, assign) NSUInteger migrationPass;

@end


@implementation MigrationManager

#pragma mark -
#pragma mark - Migration

- (BOOL)progressivelyMigrateStoreAtURL:(NSURL*)aSrcStoreURL
                                ofType:(NSString*)aType
                               toModel:(NSManagedObjectModel*)aFinalModel
                          modelsBundle:(NSBundle*)aBundle
                                 error:(NSError**)aError
{
    NSDictionary *srcMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:aType
                                                                                           URL:aSrcStoreURL
                                                                                         error:aError];
    if (!srcMetadata) return NO;

    // If store is compatible with the final model, then we're done
    if ([aFinalModel isConfiguration:nil compatibleWithStoreMetadata:srcMetadata]) {
        if (aError) *aError = nil;
        return YES;
    }

    // Look for the model that matches the source store
    NSManagedObjectModel *srcModel = [NSManagedObjectModel mergedModelFromBundles:@[aBundle]
                                                                 forStoreMetadata:srcMetadata];

    // Find an NSMappingModel that will map from the src -> dest model
    NSManagedObjectModel *destModel = nil;
    NSMappingModel *mappingModel = nil;
    NSString *modelName = nil;
    
    if (![self getDestModel:&destModel
               mappingModel:&mappingModel
                  modelName:&modelName
                forSrcModel:srcModel
               modelsBundle:aBundle
                      error:aError]) {
        return NO;
    }
    
    // IMPORTANT: Checkpoint the store by opening in rollback mode. See method comments.
    [self checkpointStoreAtURL:aSrcStoreURL withType:aType model:srcModel];
    
    // @Note: Martin Hwasser's original code from Objc.io #4 had a delegate protocol which
    //        could provide an ordered list of NSMappingModels to support multi-pass migrations
    //        of large datasets (cool!). This hasn't been implemented here since I don't need
    //        that capability at this time.

    NSURL *destStoreURL = [self destStoreURLWithSrcStoreURL:aSrcStoreURL modelName:modelName];

    NSMigrationManager *manager = [[NSMigrationManager alloc] initWithSourceModel:srcModel
                                                                 destinationModel:destModel];

    // Increment the pass number for the progress update
    self.migrationPass++;
    
    // Observe NSMigrationManager's progress and update via migration progress handler
    [self startObservingMigrationManager:manager];
    
    BOOL migrated = [manager migrateStoreFromURL:aSrcStoreURL
                                            type:aType
                                         options:nil
                                withMappingModel:mappingModel
                                toDestinationURL:destStoreURL
                                 destinationType:aType
                              destinationOptions:nil
                                           error:aError];
    
    [self stopObservingMigrationManager:manager];
    
    if (!migrated) return NO;
    
    // Final update to progress handler
    if (self.migrationProgressHandler) {
        self.migrationProgressHandler(self.migrationPass, 1.f);
    }
    
    // Migration was successful, backup src store and move dest store into place
    NSURL *backupURL = [self backupAndReplaceSrcStoreAtURL:aSrcStoreURL
                                        withDestStoreAtURL:destStoreURL
                                                     error:aError];
    if (!backupURL) {
        // The operation failed, but we tried to restore the original src store
        return NO;
    }

    // @Note: There are good arguments for keeping the store resulting from the last successful
    //        intermediate migration rather than the original store, but the user API starts
    //        to lose its simplicity: How many migrations succeeded? Which model version did
    //        we make it to?
    
    // The original src store is sacred; keep its backup in case a successive migration fails,
    // but remove intermediates to conserve disk space and maintain API simplicity.
    if (!self.originalSrcStoreBackupURL) {
        self.originalSrcStoreBackupURL = backupURL;
    }
    else {
        [[NSFileManager defaultManager] removeItemAtURL:backupURL error:nil];
    }
    
    // We may not be at the "current" model yet, so recurse
    return [self progressivelyMigrateStoreAtURL:aSrcStoreURL
                                         ofType:aType
                                        toModel:aFinalModel
                                   modelsBundle:aBundle
                                          error:aError];
}


- (BOOL)getDestModel:(NSManagedObjectModel**)aDestModel
        mappingModel:(NSMappingModel**)aMappingModel
           modelName:(NSString**)aModelName
         forSrcModel:(NSManagedObjectModel*)aSrcModel
        modelsBundle:(NSBundle*)aBundle
               error:(NSError**)aError
{
    // Get model URLs with NEWER versions than the src model sorted by ascending version
    NSArray *newerModelUrls = [self modelURLsForVersionsNewerThanModel:aSrcModel inBundle:aBundle error:aError];

    if (!newerModelUrls) {
        return NO;
    }
    
    // Find a matching destination model
    NSManagedObjectModel *destModel = nil;
    NSMappingModel *mapping = nil;
    NSURL *destModelUrl = nil;
    
    for (destModelUrl in newerModelUrls) {
        destModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:destModelUrl];

        // First look for an explicit mapping
        mapping = [NSMappingModel mappingModelFromBundles:@[aBundle]
                                           forSourceModel:aSrcModel
                                         destinationModel:destModel];
        
        // @Note: Core Data can provide an inferred mapping that will still yield
        //        a failed migration. E.g., Mandatory attributes with no default
        //        values which require validation rules that weren't provided.
        
        // If no explicit mapping, see if one can be inferred
        if (!mapping) {
            mapping = [NSMappingModel inferredMappingModelForSourceModel:aSrcModel
                                                        destinationModel:destModel
                                                                   error:nil];
        }
        
        // Stop when/if we find a mapping model
        if (mapping) break;
    }
    
    // If we can't find a suitable mapping model, set an error and give up
    if (!mapping) {
        if (aError) {
            NSString *desc = [NSString stringWithFormat:@"No mapping model found in bundle %@", aBundle];
            *aError = [NSError errorWithDomain:MWKCoreDataErrorDomain
                                          code:MWKCoreDataErrorNoMappingModelsFound
                                      userInfo:@{ NSLocalizedDescriptionKey : desc }];
        }
        
        return NO;
    }
    
    // We have a winner!
    *aDestModel = destModel;
    *aMappingModel = mapping;
    *aModelName = destModelUrl.lastPathComponent.stringByDeletingPathExtension;
    
    return YES;
}


- (NSComparator)modelURLVersionComparator
{
    if (!_modelURLVersionComparator) {
        NSComparator comparator = ^NSComparisonResult(NSURL *a, NSURL *b) {
            return [a.path compare:b.path options:NSNumericSearch];
        };
        
        _modelURLVersionComparator = comparator;
    }
    
    return _modelURLVersionComparator;
}


- (NSArray*)modelURLsInBundle:(NSBundle*)aBundle
{
    NSMutableArray *modelUrls = [NSMutableArray new];
    
    NSArray *momdUrls = [aBundle URLsForResourcesWithExtension:@"momd" subdirectory:nil];
    
    for (NSURL *momdUrl in momdUrls) {
        NSArray *models = [aBundle URLsForResourcesWithExtension:@"mom" subdirectory:momdUrl.lastPathComponent];
        [modelUrls addObjectsFromArray:models];
    }
    
    NSArray *otherModels = [aBundle URLsForResourcesWithExtension:@"mom" subdirectory:nil];
    [modelUrls addObjectsFromArray:otherModels];
    
    return modelUrls;
}


- (NSArray*)modelURLsForVersionsNewerThanModel:(NSManagedObjectModel*)aModel inBundle:(NSBundle*)aBundle error:(NSError**)aError
{
    NSArray *allModelUrls = [self modelURLsInBundle:aBundle];
    
    // If we can't find any models, set an error and give up
    if (allModelUrls.count == 0) {
        if (aError) {
            NSString *desc = [NSString stringWithFormat:@"No models found in bundle %@", aBundle];
            *aError = [NSError errorWithDomain:MWKCoreDataErrorDomain
                                          code:MWKCoreDataErrorNoManagedObjectModelFilesFound
                                      userInfo:@{ NSLocalizedDescriptionKey : desc }];
        }
        
        return nil;
    }
    
    // Sort the managed object model URLs by ascending model version
    NSArray *sortedModelUrls = [allModelUrls sortedArrayUsingComparator:self.modelURLVersionComparator];
    
    // Find model URL for the src model
    NSUInteger srcModelIdx = [sortedModelUrls indexOfObjectPassingTest:^BOOL (NSURL *aDestModelUrl, NSUInteger aIdx, BOOL *aStop) {
        NSManagedObjectModel *destModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:aDestModelUrl];
        return [aModel.entityVersionHashesByName isEqualToDictionary:destModel.entityVersionHashesByName];
    }];
    
    if (srcModelIdx == NSNotFound) {
        if (aError) {
            NSString *desc = [NSString stringWithFormat:@"Model file for source model not found in bundle %@", aBundle];
            *aError = [NSError errorWithDomain:MWKCoreDataErrorDomain
                                          code:MWKCoreDataErrorSourceManagedObjectModelFileNotFound
                                      userInfo:@{ NSLocalizedDescriptionKey : desc }];
        }
        
        return nil;
    }
    
    // Only consider model URLs with NEWER models than the src model. This prevents inferring a
    // mapping model to a version older than the src
    NSUInteger nextModelIdx = srcModelIdx + 1;
    if (nextModelIdx >= sortedModelUrls.count) {
        if (aError) {
            NSString *desc = [NSString stringWithFormat:@"No model files newer the than source model were found in bundle %@", aBundle];
            *aError = [NSError errorWithDomain:MWKCoreDataErrorDomain
                                          code:MWKCoreDataErrorNewerManagedObjectModelFilesNotFound
                                      userInfo:@{ NSLocalizedDescriptionKey : desc }];
        }
        
        return nil;
    }
    
    return [sortedModelUrls subarrayWithRange:NSMakeRange(nextModelIdx, sortedModelUrls.count - nextModelIdx)];
}


- (NSURL*)destStoreURLWithSrcStoreURL:(NSURL*)aSrcStoreURL modelName:(NSString*)aModelName
{
    // We have a mapping model, time to migrate
    NSString *storeExtension = aSrcStoreURL.path.pathExtension;
    NSString *storePath = aSrcStoreURL.path.stringByDeletingPathExtension;
    // Build a path to write the new store
    storePath = [NSString stringWithFormat:@"%@.%@.%@", storePath, aModelName, storeExtension];
    return [NSURL fileURLWithPath:storePath];
}


- (NSURL*)backupAndReplaceSrcStoreAtURL:(NSURL*)aSrcStoreURL
                     withDestStoreAtURL:(NSURL*)aDestStoreURL
                                  error:(NSError**)aError
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // Get a tmp file URL for a backup of the src store
    NSString *tmp = [NSString stringWithFormat:@"%@_%@", [[NSProcessInfo processInfo] globallyUniqueString], @"backup"];
    NSURL *backupUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:tmp]];

    // Backup src store to tmp file
    if (![fm moveItemAtURL:aSrcStoreURL toURL:backupUrl error:aError]) {
        return nil;
    }
    
    // Move dest to src
    if (![fm moveItemAtURL:aDestStoreURL toURL:aSrcStoreURL error:aError]) {
        // Move failed, try to back out by moving original file back into place
        [fm moveItemAtURL:backupUrl toURL:aSrcStoreURL error:nil];
        return nil;
    }
    
    return backupUrl;
}


// There are/were some bugs around "heavyweight" migrations related to WAL mode of SQLite stores
// -- supposedly fixed in iOS 8.2/OSX 10.10.2:
// http://www.openradar.me/radar?id=5521374336516096,
// But there are also other older mentions of similar bugs:
// http://pablin.org/2013/05/24/problems-with-core-data-migration-manager-and-journal-mode-wal/
// Since there's been lots of pain on this front, we'll use this to open up the store in the in
// rollback mode to force Core Data to checkpoint as per
// https://developer.apple.com/library/mac/qa/qa1809/_index.html
// This also ensures we're dealing with only the single SQLite file (no sidecar wal/shm files) so
// that we can back up the store with standard file operations during migration.

- (void)checkpointStoreAtURL:(NSURL*)aStoreURL
                    withType:(NSString*)aStoreType
                       model:(NSManagedObjectModel*)aModel

{
    if (![aStoreType isEqualToString:NSSQLiteStoreType]) return;
    
    // Use a tmp persistent store coordinator to open SQLite in rollback mode, rather than WAL mode.
    // "This will force Core Data to perform a checkpoint operation, which merges the in the -wal
    // file to store file" -- Apple Technical QA1809
    NSDictionary *options = @{NSSQLitePragmasOption : @{@"journal_mode" : @"DELETE"}};
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:aModel];
    
    [psc addPersistentStoreWithType:NSSQLiteStoreType
                      configuration:nil
                                URL:aStoreURL
                            options:options
                              error:nil];
    
    // We're done with the store and the psc
    if (psc) [psc removePersistentStore:[psc persistentStoreForURL:aStoreURL] error:nil];
}


- (void)startObservingMigrationManager:(NSMigrationManager*)aManager
{
    if (!self.migrationProgressHandler) return;
    NSString *progressKey = NSStringFromSelector(@selector(migrationProgress));
    [aManager addObserver:self
               forKeyPath:progressKey
                  options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial
                  context:kMigrationProgressCtx];
}


- (void)stopObservingMigrationManager:(NSMigrationManager*)aManager
{
    if (!self.migrationProgressHandler) return;
    NSString *progressKey = NSStringFromSelector(@selector(migrationProgress));
    [aManager removeObserver:self forKeyPath:progressKey context:kMigrationProgressCtx];
}


- (void)observeValueForKeyPath:(NSString*)aKeyPath
                      ofObject:(id)aObject
                        change:(NSDictionary*)aChange
                       context:(void*)aCtx
{
    if (self.migrationProgressHandler && aCtx == kMigrationProgressCtx) {
        self.migrationProgressHandler(self.migrationPass, [aObject migrationProgress]);
    }
    else {
        [super observeValueForKeyPath:aKeyPath ofObject:aObject change:aChange context:aCtx];
    }
}

@end
