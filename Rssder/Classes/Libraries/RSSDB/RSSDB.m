//
//  RSSDB.m
//  iOS SQLite Sandbox
//  Rssder
//
//  Created by yangfei on 11-6-27.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RSSDB.h"

@implementation RSSDB
@synthesize idList;

static NSString * const kFeedTableName = @"feed";
static NSString * const kItemTableName = @"item";

static NSString * const kDBFeedUrlKey = @"url";
static NSString * const kDBItemUrlKey = @"url";
static NSString * const kDBItemFeedIDKey = @"feed_id";

#pragma mark Instance methods

- (void)dealloc {
    // NSLog(@"%s", __FUNCTION__);
    [super dealloc];
    if (idList) [idList release];
}

- (RSSDB *) initWithRSSDBFilename: (NSString *) fn {
    // NSLog(@"%s", __FUNCTION__);
    if ((self = (RSSDB *) [super initWithDBFilename:fn])) {
        idList = [[NSMutableArray alloc] init];
    }
    [self setDefaults];
    return self;
}

- (NSString *) getVersion {
    return kRSSDBVersion;
}

- (void) setDefaults {
    // NSLog(@"%s", __FUNCTION__);
    [self addNewIndex];
}

- (NSNumber *) getMaxItemsPerFeed {
    // NSLog(@"%s", __FUNCTION__);
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *maxItemsPerFeed = [defaults objectForKey:@"max_items_per_feed"];
    // the device doesn't initialize standardUserDefaults until the preference pane has been visited once
    if (!maxItemsPerFeed) maxItemsPerFeed = [NSNumber numberWithInt: kDefaultMaxItemsPerFeed];
    return maxItemsPerFeed;
}

// add index for old version of the DB
- (void) addNewIndex {
    // NSLog(@"%s", __FUNCTION__);
    [self doQuery:@"CREATE UNIQUE INDEX IF NOT EXISTS feedUrl ON feed(url)"];
}

#pragma mark -
#pragma mark Feed methods

- (NSArray *) getFeedIDs {
    // NSLog(@"%s", __FUNCTION__);
    NSDictionary * row;
    [idList removeAllObjects];  // reset the array
    for (row in [self getQuery:@"SELECT id FROM feed ORDER BY LOWER(title)"]) {
        [idList addObject:[row objectForKey:@"id"]];
    }
    return idList;
}

- (NSDictionary *) getFeedRow: (NSNumber *) rowid {
    // NSLog(@"%s", __FUNCTION__);
    self.tableName = kFeedTableName;
    return [self getRow:rowid];
}

- (void) deleteFeedRow: (NSNumber *) rowid {
    // NSLog(@"%s", __FUNCTION__);
    [self doQuery:@"DELETE FROM item WHERE feed_id = ?", rowid];
    [self doQuery:@"DELETE FROM feed WHERE id = ?", rowid];
}

- (NSNumber *) addFeedRow: (NSDictionary *) feed { 
    // NSLog(@"%s", __FUNCTION__);
    self.tableName = kFeedTableName;
    NSNumber * rowid = [self valueFromQuery:@"SELECT id FROM feed WHERE url = ?", [feed objectForKey:kDBFeedUrlKey]];
    if (rowid) {
        [self updateRow:feed :rowid];
        return rowid;
    } else {
        [self insertRow:feed];
        return nil;     // indicate that it's a new row
    }
}

- (void) updateFeed: (NSDictionary *) feed forRowID: (NSNumber *) rowid {
    // NSLog(@"%s", __FUNCTION__);
    self.tableName = kFeedTableName;
    NSDictionary * rec = [NSDictionary dictionaryWithObjectsAndKeys:
                        [feed objectForKey:@"title"], @"title",
                        [feed objectForKey:@"desc"], @"desc", nil];
    [self updateRow:rec :rowid];
}

#pragma mark -
#pragma mark Item methods

- (NSDictionary *) getItemRow: (NSNumber *) rowid {
    // NSLog(@"%s", __FUNCTION__);
    self.tableName = kItemTableName;
    return [self getRow:rowid];
}

- (void) deleteItemRow: (NSNumber *) rowid {
    // NSLog(@"%s", __FUNCTION__);
    self.tableName = kItemTableName;
    [self deleteRow:rowid];
}

- (void) deleteOldItems:(NSNumber *)feedID {
    // NSLog(@"%s", __FUNCTION__);
    [self doQuery:@"DELETE FROM item WHERE feed_id = ? AND id NOT IN "
         @"(SELECT id FROM item WHERE feed_id = ? ORDER BY pubdate DESC LIMIT ?)",
         feedID, feedID, [self getMaxItemsPerFeed]];
}

- (NSArray *) getItemIDs:(NSNumber *)feedID {
    // NSLog(@"%s", __FUNCTION__);
    NSDictionary * row;
    [idList removeAllObjects];  // reset the array
    for (row in [self getQuery:@"SELECT id FROM item WHERE feed_id = ? ORDER BY pubdate DESC", feedID]) {
        [idList addObject:[row objectForKey:@"id"]];
    }
    return idList;
}

- (NSNumber *) addItemRow: (NSDictionary *) item {
    // NSLog(@"%s", __FUNCTION__);
    self.tableName = kItemTableName;
    NSNumber * rowid = [self valueFromQuery:@"SELECT id FROM item WHERE url = ? AND feed_id = ?",
                        [item objectForKey:kDBItemUrlKey], [item objectForKey:kDBItemFeedIDKey]];
    if (rowid) {
        [self updateRow:item :rowid];
        return rowid;
    } else {
        [self insertRow:item];
        return nil;     // indicate that it's a new row
    }
}

- (NSNumber *) countItems:(NSNumber *)feedID {
    // NSLog(@"%s", __FUNCTION__);
    return [self valueFromQuery:@"SELECT COUNT(*) FROM item WHERE feed_id = ?", feedID];
}

@end
