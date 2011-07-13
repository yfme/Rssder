//
//  RssderWebViewController.h
//  Rssder
//
//  Created by yangfei on 11-7-13.
//  Copyright 2011年 appxyz.com. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface RssderWebViewController : UIViewController <UIWebViewDelegate> {
    IBOutlet UIWebView *myWebView;
    IBOutlet UIBarButtonItem *backButton;
    IBOutlet UIBarButtonItem *forwardButton;
    NSString *urlString;
    NSDictionary *feedItem;
}

@property (nonatomic, retain) UIWebView *myWebView;
@property (nonatomic, retain) NSString *urlString;
@property (nonatomic, retain) NSDictionary *feedItem;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *backButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *forwardButton;

- (IBAction) launchSafari:(id)sender;

@end
