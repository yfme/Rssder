//
//  RSSDB.h
//  Rssder
//
//  Created by yangfei on 11-6-27.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BWDB.h"
#import "BWUtilities.h"

static NSString * const kRSSDBVersion = @"1.0.2";
static NSUInteger const kDefaultMaxItemsPerFeed = 50;

@interface RSSDB : BWDB {
    NSMutableArray * idList;
}

@property (nonatomic, retain) NSMutableArray * idList;

- (RSSDB *) initWithRSSDBFilename: (NSString *) fn;
- (NSString *) getVersion;
- (NSArray *) getFeedIDs;
- (void) setDefaults;
- (NSNumber *) getMaxItemsPerFeed;
- (void) addNewIndex;

// Feed methods
- (NSDictionary *) getFeedRow: (NSNumber *) rowid;
- (void) deleteFeedRow: (NSNumber *) rowid;
- (NSNumber *) addFeedRow: (NSDictionary *) feed;
- (void) updateFeed: (NSDictionary *) feed forRowID: (NSNumber *) rowid;

// Item methods
- (NSDictionary *) getItemRow: (NSNumber *) rowid;
- (void) deleteItemRow: (NSNumber *) rowid;
- (void) deleteOldItems:(NSNumber *)feedID;
- (NSArray *) getItemIDs:(NSNumber *)feedID;
- (NSNumber *) addItemRow: (NSDictionary *) item;
- (NSNumber *) countItems:(NSNumber *)feedID;

@end
