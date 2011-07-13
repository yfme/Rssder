//
//  RssderAddViewController.h
//  Rssder
//
//  Created by yangfei on 11-7-1.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BWUtilities.h"
#import "RSSDB.h"

// page size constants
static NSUInteger const minPageSize = 64;
static NSUInteger const maxPageSize = 10240;

// state flag constants (can't use int const in a switch)
#define BWRSS_STATE_DISCOVERY 1
#define BWRSS_STATE_PARSE_HEADER 2

@protocol RssderAddViewControllerDelegate
-(void) haveAddViewRecord:(NSDictionary *) avRecord;
-(void) haveAddViewURLError:(NSError *) error;
-(void) haveAddViewRSSError:(NSString *) message;
@end

@interface RssderAddViewController : UIViewController <NSXMLParserDelegate> {
    UITextField *urlField;
    UILabel *labelStatus;
    
    id <RssderAddViewControllerDelegate> delegate;
    RSSDB *rssDB;
    UITableView *rssTableView;
    NSURLConnection *feedConnection;
    NSMutableData *xmlData;
    NSMutableDictionary *feedRecord;
    NSString *feedURL;
    NSString *feedHost;
    
@private
    BOOL didAbortParsing;
    BOOL didReturnFeed;
    BOOL haveTitle;
    BOOL haveDescripton;
    NSInteger bwrssState;   // used for NSConnection
    NSString *currentElement;
}

@property (nonatomic, retain) IBOutlet UITextField *urlField;
@property (nonatomic, retain) IBOutlet UILabel *labelStatus;

@property (nonatomic, assign) id <RssderAddViewControllerDelegate> delegate;
@property (nonatomic, retain) RSSDB *rssDB;
@property (nonatomic, retain) UITableView *rssTableView;

@property (nonatomic, retain) NSURLConnection *feedConnection;
@property (nonatomic, retain) NSMutableData *xmlData;
@property (nonatomic, retain) NSMutableDictionary *feedRecord;
@property (nonatomic, retain) NSString *feedURL;
@property (nonatomic, retain) NSString *feedHost;

- (IBAction)addFeedButtonPressed:(id)sender;
- (IBAction)cancelButtonPressed:(id)sender;

// RSS Feed management
- (void) getRSSFeed:(NSString *) url;
- (void) fetchURL:(NSString *) url withState:(BOOL) urlState;

// RSS discovery methods
- (NSDictionary *) rssLinkFromHTML:(NSString *) htmlString;
- (NSDictionary *) getAttributes:(NSString *) htmlTag;

// Error handling
- (void) handleURLError:(NSError *)error;
- (void) errorAlert:(NSString *) message;

// Utilities
- (void) statusMessage:(NSString *) format, ...;
- (void) clearStatusMessage;

@end
