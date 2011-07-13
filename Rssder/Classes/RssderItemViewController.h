//
//  RssderItemViewController.h
//  Rssder
//
//  Created by yangfei on 11-6-29.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSSDB.h"
#import "RssderWebViewController.h"

@interface RssderItemViewController : UITableViewController <NSXMLParserDelegate> {
    RSSDB *rssDB;
    NSNumber *feedID;
    NSDictionary *feedRecord;
    NSDictionary *itemRecord;
    NSArray *itemRowIDs;
    
    // Connection properties
    NSURLConnection *rssConnection;
    NSMutableData *rssData;
    
    // parser properties
    NSUInteger parsedItemsCounter;
    NSMutableArray *currentParseBatch;
    NSMutableString *currentParsedCharacterData;
    NSMutableDictionary *currentItemObject;
    NSMutableDictionary *currentFeedObject;
    BOOL accumulatingParsedCharacterData;
    BOOL didAbortParsing;
}

@property (nonatomic, retain) RSSDB *rssDB;
@property (nonatomic, retain) NSNumber *feedID;
@property (nonatomic, retain) NSDictionary *feedRecord;
@property (nonatomic, retain) NSDictionary *itemRecord;
@property (nonatomic, retain) NSArray *itemRowIDs;

@property (nonatomic, retain) NSURLConnection *rssConnection;
@property (nonatomic, retain) NSMutableData *rssData;

@property (nonatomic, retain) NSMutableArray *currentParseBatch;
@property (nonatomic, retain) NSMutableString *currentParsedCharacterData;
@property (nonatomic, retain) NSMutableDictionary *currentItemObject;
@property (nonatomic, retain) NSMutableDictionary *currentFeedObject;

// Date parsing methods
-(NSString *) dateToLocalizedString:(NSDate *) date;
-(NSDate *) SQLDateToDate:(NSString *) SQLDateString;
-(NSString *) dateStringToSQLDate:(NSString *) dateString;


// Error handling
- (void)handleError:(NSError *)error;
- (void)errorAlert:(NSString *) message;

// Support methods
- (void) loadRSSFeed;

@end
