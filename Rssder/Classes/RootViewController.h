//
//  RootViewController.h
//  Rssder
//
//  Created by yangfei on 11-6-27.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RSSDB.h"
#import "RssderItemViewController.h"
#import "RssderAddViewController.h"

@interface RootViewController : UITableViewController <RssderAddViewControllerDelegate> {
    RSSDB *rssDB;
    NSArray *feedIDs;
}

@property (nonatomic, retain) RSSDB *rssDB;
@property (nonatomic, retain) NSArray *feedIDs;

- (NSArray *) loadFeedIDs;
- (NSArray *) loadFeedIDsIfEmpty;
- (RSSDB *) loadFeedDB;

@end
