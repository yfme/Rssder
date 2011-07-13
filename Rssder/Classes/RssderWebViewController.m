//
//  RssderWebViewController.m
//  Rssder
//
//  Created by yangfei on 11-7-13.
//  Copyright 2011年 appxyz.com. All rights reserved.
//

#import "RssderWebViewController.h"


@implementation RssderWebViewController

@synthesize myWebView, urlString, feedItem, backButton, forwardButton;

- (IBAction) launchSafari:(id)sender {
    NSLog(@"%s", __FUNCTION__);
    // to load original page in Safari
    // [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[feedItem valueForKey:kDBItemUrlKey]]];
    
    // to load current page in Safari
    // [[UIApplication sharedApplication] openURL:[[myWebView request] URL]];
}

@end
